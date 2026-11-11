# frozen_string_literal: true

module Elido
  module Resources
    # Outbound webhook subscriptions (CRUD + secret rotation).
    #
    # NOTE: the workspace-scoped webhook routes are not yet enumerated
    # in the published OpenAPI spec; shapes may tighten later.
    class Webhooks
      def initialize(client)
        @client = client
      end

      def list(workspace_id:)
        @client.get("/v1/workspaces/#{workspace_id}/webhooks")
      end

      def create(workspace_id:, url:, events:, idempotency_key: nil, **extra)
        @client.post(
          "/v1/workspaces/#{workspace_id}/webhooks",
          body: { url: url, events: events, **extra },
          idempotency_key: idempotency_key,
        )
      end

      def get(workspace_id:, webhook_id:)
        @client.get(
          "/v1/workspaces/#{workspace_id}/webhooks/#{webhook_id}",
        )
      end

      def update(workspace_id:, webhook_id:, **patch)
        @client.patch(
          "/v1/workspaces/#{workspace_id}/webhooks/#{webhook_id}",
          body: patch,
        )
      end

      def delete(workspace_id:, webhook_id:)
        @client.delete(
          "/v1/workspaces/#{workspace_id}/webhooks/#{webhook_id}",
        )
      end

      # Rotate the signing secret. Old secret stays valid for a
      # 24h grace window; the dispatcher signs with both during the
      # overlap so receivers can swap without downtime.
      def rotate_secret(workspace_id:, webhook_id:, idempotency_key: nil)
        @client.post(
          "/v1/workspaces/#{workspace_id}/webhooks/#{webhook_id}/rotate-secret",
          idempotency_key: idempotency_key,
        )
      end
    end
  end
end
