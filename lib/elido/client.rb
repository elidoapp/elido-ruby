# frozen_string_literal: true

require "faraday"
require "json"
require "securerandom"

require_relative "error"
require_relative "resources/users"
require_relative "resources/workspaces"
require_relative "resources/links"
require_relative "resources/folders"
require_relative "resources/api_keys"
require_relative "resources/invitations"
require_relative "resources/analytics"
require_relative "resources/billing"
require_relative "resources/pixels"
require_relative "resources/compliance"
require_relative "resources/domains"
require_relative "resources/qr"
require_relative "resources/campaigns"
require_relative "resources/bio"
require_relative "resources/members"
require_relative "resources/webhooks"

module Elido
  # Default base URL — the public Elido API. Self-hosted
  # users override via `base_url:`.
  DEFAULT_BASE_URL = "https://api.elido.app"
  DEFAULT_TIMEOUT  = 30

  # Module-level singleton config used by Elido.configure. The
  # convention mirrors `Stripe.api_key` / `Sentry.init` — handy when
  # you have a single workspace and don't want to pass a client
  # around as an argument.
  class Configuration
    attr_accessor :api_key, :base_url, :timeout, :user_agent,
                  :analytics_base_url, :billing_base_url, :qr_base_url

    def initialize
      @base_url = DEFAULT_BASE_URL
      @timeout = DEFAULT_TIMEOUT
      @user_agent = "elido-ruby/#{Elido::VERSION}"
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    # Block form: `Elido.configure { |c| c.api_key = "..." }`.
    def configure
      yield(configuration)
      @default_client = nil # reset on reconfigure
    end

    # Lazy singleton — built on first access from whatever was set
    # via `configure`. Reset implicitly when `configure` is called
    # again so tests can re-stub auth between examples.
    def default_client
      @default_client ||= Client.new(
        api_key: configuration.api_key,
        base_url: configuration.base_url,
        timeout: configuration.timeout,
        user_agent: configuration.user_agent,
        analytics_base_url: configuration.analytics_base_url,
        billing_base_url: configuration.billing_base_url,
        qr_base_url: configuration.qr_base_url,
      )
    end

    # Test helper — does NOT clear `configuration`, only the
    # memoized client. Used by the spec suite.
    def reset_default_client!
      @default_client = nil
    end
  end

  # Top-level HTTP client. Holds:
  #   * Faraday connections for each backend host (most deploys
  #     share a single hostname — separate hosts are an
  #     enterprise / self-host pattern).
  #   * Resource namespaces (`#links`, `#analytics`, …).
  #
  # The class is intentionally thin: argument shaping + path
  # templating + idempotency-key plumbing live here, anything
  # response-shape-related lives in the caller. We don't auto-retry
  # on 429 / 5xx because mutating verbs (POST / PATCH / DELETE)
  # aren't idempotent unless the caller has supplied an
  # `idempotency_key` — and even then it's the caller's policy.
  class Client
    attr_reader :base_url, :timeout, :user_agent

    def initialize(
      api_key: nil,
      base_url: DEFAULT_BASE_URL,
      timeout: DEFAULT_TIMEOUT,
      user_agent: nil,
      cookie: nil,
      dev_user_id: nil,
      analytics_base_url: nil,
      billing_base_url: nil,
      qr_base_url: nil,
      adapter: nil,
      logger: nil
    )
      @api_key = api_key
      @cookie = cookie
      @dev_user_id = dev_user_id
      @base_url = _strip(base_url)
      @analytics_base_url = _strip(analytics_base_url || base_url)
      @billing_base_url = _strip(billing_base_url || base_url)
      @qr_base_url = _strip(qr_base_url || base_url)
      @timeout = timeout
      @user_agent = user_agent || "elido-ruby/#{Elido::VERSION}"
      @adapter = adapter || Faraday.default_adapter
      @logger = logger

      @connections = {}

      # Resource namespaces — every resource gets the parent Client
      # by reference so we don't copy auth state.
      @users        = Resources::Users.new(self)
      @workspaces   = Resources::Workspaces.new(self)
      @links        = Resources::Links.new(self)
      @folders      = Resources::Folders.new(self)
      @api_keys     = Resources::ApiKeys.new(self)
      @invitations  = Resources::Invitations.new(self)
      @analytics    = Resources::Analytics.new(self)
      @billing      = Resources::Billing.new(self)
      @pixels       = Resources::Pixels.new(self)
      @compliance   = Resources::Compliance.new(self)
      @domains      = Resources::Domains.new(self)
      @qr           = Resources::Qr.new(self)
      @campaigns    = Resources::Campaigns.new(self)
      @bio          = Resources::Bio.new(self)
      @members      = Resources::Members.new(self)
      @webhooks     = Resources::Webhooks.new(self)
    end

    # === Resource accessors =================================================

    attr_reader :users, :workspaces, :links, :folders, :api_keys,
                :invitations, :analytics, :billing, :pixels, :compliance,
                :domains, :qr, :campaigns, :bio, :members, :webhooks

    # === Low-level request plumbing =========================================
    #
    # Resource classes call `request(:get, "/v1/...", params:, body:)` or one
    # of the verb shortcuts below. They never touch Faraday directly. This
    # gives us a single place to:
    #
    #   * inject Authorization / Cookie / X-Dev-User-ID headers,
    #   * mint an Idempotency-Key when the caller didn't supply one on POST,
    #   * map non-2xx responses to typed exceptions,
    #   * forward X-Request-ID into exceptions.

    def get(path, params: nil, base: :api)
      request(:get, path, params: params, base: base)
    end

    def post(path, body: nil, params: nil, idempotency_key: nil, base: :api)
      request(:post, path, body: body, params: params,
                           idempotency_key: idempotency_key, base: base)
    end

    def patch(path, body: nil, params: nil, base: :api)
      request(:patch, path, body: body, params: params, base: base)
    end

    def put(path, body: nil, params: nil, base: :api)
      request(:put, path, body: body, params: params, base: base)
    end

    def delete(path, params: nil, base: :api)
      request(:delete, path, params: params, base: base)
    end

    def request(method, path, body: nil, params: nil, idempotency_key: nil, base: :api)
      conn = _connection_for(base)
      response =
        begin
          conn.run_request(method, path, nil, nil) do |req|
            req.params.update(_compact(params)) if params
            req.headers.merge!(_request_headers(method: method,
                                                has_body: !body.nil?,
                                                idempotency_key: idempotency_key))
            req.body = JSON.generate(body) unless body.nil?
            req.options.timeout = @timeout if @timeout
          end
        rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::SSLError => e
          raise ConnectionError.new("#{method.to_s.upcase} #{path}: #{e.message}", cause_error: e)
        end

      _handle_response(response, method: method, path: path)
    end

    private

    def _strip(url)
      return nil if url.nil?

      url.to_s.sub(%r{/+\z}, "")
    end

    def _connection_for(base)
      url = case base
            when :api       then @base_url
            when :analytics then @analytics_base_url
            when :billing   then @billing_base_url
            when :qr        then @qr_base_url
            else raise ArgumentError, "unknown base: #{base.inspect}"
            end

      @connections[base] ||= Faraday.new(url: url) do |f|
        f.response :logger, @logger if @logger
        f.adapter @adapter
      end
    end

    def _request_headers(method:, has_body:, idempotency_key:)
      headers = {
        "Accept" => "application/json",
        "User-Agent" => @user_agent,
      }
      headers["Content-Type"] = "application/json" if has_body

      if @api_key
        headers["Authorization"] = "Bearer #{@api_key}"
      elsif @cookie
        headers["Cookie"] = @cookie
      elsif @dev_user_id
        headers["X-Dev-User-ID"] = @dev_user_id.to_s
      end

      # POSTs are non-idempotent unless the server gets a stable
      # Idempotency-Key. Auto-generate if the caller didn't supply
      # one — at-most-once semantics are then on by default and a
      # retry from a network hiccup won't double-create a link.
      if method == :post
        headers["Idempotency-Key"] = idempotency_key || SecureRandom.uuid
      end

      headers
    end

    def _compact(params)
      return {} unless params.is_a?(Hash)

      out = {}
      params.each do |k, v|
        next if v.nil?

        out[k] = case v
                 when Array then v.join(",")
                 when true, false then v.to_s
                 else v
                 end
      end
      out
    end

    def _handle_response(response, method:, path:)
      status = response.status
      raw    = response.body
      parsed = _parse_body(raw, response.headers["content-type"])
      request_id = response.headers["x-request-id"] || response.headers["X-Request-ID"]

      return nil if status == 204
      return parsed if status >= 200 && status < 300

      _raise_for_status(
        status: status,
        body: parsed,
        request_id: request_id,
        response_headers: response.headers,
        method: method,
        path: path,
      )
    end

    def _parse_body(raw, content_type)
      return nil if raw.nil? || raw.to_s.empty?
      return raw unless content_type.to_s.include?("application/json")

      JSON.parse(raw)
    rescue JSON::ParserError
      raw
    end

    def _raise_for_status(status:, body:, request_id:, response_headers:, method:, path:)
      message = _extract_message(body) || "#{method.to_s.upcase} #{path} → #{status}"
      common = {
        status: status,
        body: body,
        request_id: request_id,
        response_headers: response_headers,
      }

      case status
      when 401
        raise AuthenticationError.new(message, **common)
      when 403
        raise PermissionError.new(message, **common)
      when 404
        raise NotFoundError.new(message, **common)
      when 409
        raise ConflictError.new(message, **common)
      when 422
        raise ValidationError.new(message, **common)
      when 429
        retry_after = response_headers["retry-after"] || response_headers["Retry-After"]
        raise RateLimitError.new(message, **common, retry_after: (retry_after&.to_i))
      when 500..599
        raise ServerError.new(message, **common)
      else
        raise ApiError.new(message, **common)
      end
    end

    def _extract_message(body)
      return nil unless body.is_a?(Hash)

      msg = body["error"] || body[:error] || body["message"] || body[:message]
      msg.is_a?(String) ? msg : nil
    end
  end
end
