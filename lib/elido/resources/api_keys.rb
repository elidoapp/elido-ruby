# frozen_string_literal: true

module Elido
  module Resources
    # Workspace-scoped API key management. The plaintext key value
    # comes back exactly once on `create` — it's stored hashed
    # server-side. Rotate by `create` + `revoke(old_id)`.
    class ApiKeys
      def initialize(client)
        @client = client
      end

      def list(workspace_id:)
        @client.get("/v1/workspaces/#{workspace_id}/api-keys")
      end

      def create(workspace_id:, name:, role: "editor", idempotency_key: nil)
        @client.post(
          "/v1/workspaces/#{workspace_id}/api-keys",
          body: { name: name, role: role },
          idempotency_key: idempotency_key,
        )
      end

      def revoke(workspace_id:, key_id:)
        @client.delete("/v1/workspaces/#{workspace_id}/api-keys/#{key_id}")
      end
    end
  end
end
