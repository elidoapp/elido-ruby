# frozen_string_literal: true

require_relative "../pagination"

module Elido
  module Resources
    # `/v1/workspaces/{ws}/links` — the core CRUD surface for the
    # shortened links themselves.
    class Links
      include Elido::Pagination

      def initialize(client)
        @client = client
      end

      # GET /v1/workspaces/{ws}/links. Pass `tags:` as an Array — the
      # client comma-joins; the API uses CSV for multi-tag filter.
      #
      # The wire endpoint uses offset+limit pagination (no cursor) — see
      # PaginatedLinks in models.py. `each` here drives that loop.
      def list(workspace_id:, limit: nil, offset: nil, tags: nil, q: nil, folder: nil)
        params = { limit: limit, offset: offset, q: q, tags: tags, folder: folder }
        @client.get("/v1/workspaces/#{workspace_id}/links", params: params)
      end

      # Auto-paginates list() and yields each link hash. Returns an
      # Enumerator if no block is given so callers can do `.lazy.map(...)`.
      def each(workspace_id:, **filters, &block)
        return enum_for(:each, workspace_id: workspace_id, **filters) unless block

        @paginate_ws_id = workspace_id
        @paginate_filters = filters
        paginate(initial_params: filters, &block)
      ensure
        @paginate_ws_id = nil
        @paginate_filters = nil
      end

      def yield_page(params)
        list(workspace_id: @paginate_ws_id, **params)
      end

      # POST /v1/workspaces/{ws}/links. The OpenAPI spec calls the
      # destination field `original_url` (legacy carry-over from
      # the Django prototype); the wire field is the same.
      def create(workspace_id:, original_url: nil, slug: nil, domain_id: nil,
                 tags: nil, title: nil, idempotency_key: nil, **extra)
        body = {
          original_url: original_url,
          slug: slug,
          domain_id: domain_id,
          tags: tags,
          title: title,
          **extra,
        }.compact
        @client.post(
          "/v1/workspaces/#{workspace_id}/links",
          body: body,
          idempotency_key: idempotency_key,
        )
      end

      def get(workspace_id:, link_id:)
        @client.get("/v1/workspaces/#{workspace_id}/links/#{link_id}")
      end

      def update(workspace_id:, link_id:, **patch)
        @client.patch(
          "/v1/workspaces/#{workspace_id}/links/#{link_id}",
          body: patch,
        )
      end

      def delete(workspace_id:, link_id:)
        @client.delete("/v1/workspaces/#{workspace_id}/links/#{link_id}")
      end

      # POST /v1/workspaces/{ws}/links/bulk — accepts up to 1000 link
      # specs in one round-trip. Server is rate-limited to 5 calls/min
      # per workspace; this method does not throttle.
      def bulk_create(workspace_id:, domain_id:, links:, idempotency_key: nil)
        @client.post(
          "/v1/workspaces/#{workspace_id}/links/bulk",
          body: { domain_id: domain_id, links: links },
          idempotency_key: idempotency_key,
        )
      end

      # POST /v1/workspaces/{ws}/links/bulk-mutate — re-tag / archive
      # / move many links by id-set in one call.
      def bulk_mutate(workspace_id:, idempotency_key: nil, **body)
        @client.post(
          "/v1/workspaces/#{workspace_id}/links/bulk-mutate",
          body: body,
          idempotency_key: idempotency_key,
        )
      end

      # POST /v1/workspaces/{ws}/links/suggest-slug — AI / heuristic
      # slug suggestion endpoint. Cheap, no idempotency-key needed
      # since the server doesn't mutate state.
      def suggest_slug(workspace_id:, original_url:)
        @client.post(
          "/v1/workspaces/#{workspace_id}/links/suggest-slug",
          body: { original_url: original_url },
        )
      end
    end
  end
end
