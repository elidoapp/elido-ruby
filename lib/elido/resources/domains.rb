# frozen_string_literal: true

module Elido
  module Resources
    # Custom domain ("brand domain") management.
    #
    # Only the workspace-scoped list / create endpoints are exposed
    # here today; per-domain CRUD (verify, update, delete) is gated on
    # the workspace plan.
    class Domains
      def initialize(client)
        @client = client
      end

      def list(workspace_id:)
        @client.get("/v1/workspaces/#{workspace_id}/domains")
      end

      def create(workspace_id:, hostname:, idempotency_key: nil, **extra)
        @client.post(
          "/v1/workspaces/#{workspace_id}/domains",
          body: { hostname: hostname, **extra },
          idempotency_key: idempotency_key,
        )
      end

      # GET /v1/workspaces/{ws}/domains/{id}/app-links — iOS / Android
      # universal-link associations served from the brand domain.
      def app_links(workspace_id:, domain_id:)
        @client.get(
          "/v1/workspaces/#{workspace_id}/domains/#{domain_id}/app-links",
        )
      end
    end
  end
end
