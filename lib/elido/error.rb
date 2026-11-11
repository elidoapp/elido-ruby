# frozen_string_literal: true

module Elido
  # Base class for everything the SDK can raise. Transport-level
  # failures (DNS, TLS, read-timeout) get raised as ConnectionError;
  # any non-2xx wire response gets raised as a subclass of ApiError
  # picked by status code.
  class Error < StandardError; end

  # Raised when Faraday itself fails before we ever see a response —
  # DNS errors, socket timeouts, the works. Always retryable.
  class ConnectionError < Error
    attr_reader :cause_error

    def initialize(message, cause_error: nil)
      super(message)
      @cause_error = cause_error
    end
  end

  # 4xx / 5xx response. `body` is the parsed JSON when available, the
  # raw string otherwise. `request_id` is propagated from the
  # `X-Request-ID` response header (the API generates one per request)
  # so callers can quote it in support tickets without grepping logs.
  class ApiError < Error
    attr_reader :status, :body, :request_id, :response_headers

    def initialize(message, status:, body: nil, request_id: nil, response_headers: nil)
      super(message)
      @status = status
      @body = body
      @request_id = request_id
      @response_headers = response_headers || {}
    end

    def to_s
      base = "Elido API #{status}: #{super}"
      request_id ? "#{base} (request_id=#{request_id})" : base
    end
  end

  # 401 — missing / invalid / expired credential.
  class AuthenticationError < ApiError; end

  # 403 — authenticated but the principal is not allowed.
  class PermissionError < ApiError; end

  # 404 — resource doesn't exist or the caller can't see it.
  class NotFoundError < ApiError; end

  # 409 — write conflict (slug taken, optimistic-locking version
  # mismatch, etc.).
  class ConflictError < ApiError; end

  # 422 — body validated but failed business rules. `errors` is the
  # `errors:` map the API returns (`{"field" => ["msg", ...]}`).
  class ValidationError < ApiError
    attr_reader :errors

    def initialize(message, status:, body: nil, request_id: nil, response_headers: nil, errors: nil)
      super(message, status: status, body: body, request_id: request_id, response_headers: response_headers)
      @errors = errors || _extract_errors(body) || {}
    end

    private

    def _extract_errors(body)
      return nil unless body.is_a?(Hash)

      body["errors"] || body[:errors]
    end
  end

  # 429 — global or per-key rate limit. `retry_after` is parsed from
  # the `Retry-After` response header (integer seconds, RFC 7231).
  class RateLimitError < ApiError
    attr_reader :retry_after

    def initialize(message, status:, body: nil, request_id: nil, response_headers: nil, retry_after: nil)
      super(message, status: status, body: body, request_id: request_id, response_headers: response_headers)
      @retry_after = retry_after
    end
  end

  # 5xx — server-side fault. Caller can retry idempotent verbs.
  class ServerError < ApiError; end
end
