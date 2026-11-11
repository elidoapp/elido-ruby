# frozen_string_literal: true

module Elido
  module Resources
    class Invitations
      def initialize(client)
        @client = client
      end

      def list(workspace_id:)
        @client.get("/v1/workspaces/#{workspace_id}/invitations")
      end

      def create(workspace_id:, email:, role:, idempotency_key: nil)
        @client.post(
          "/v1/workspaces/#{workspace_id}/invitations",
          body: { email: email, role: role },
          idempotency_key: idempotency_key,
        )
      end

      def revoke(workspace_id:, invitation_id:)
        @client.delete(
          "/v1/workspaces/#{workspace_id}/invitations/#{invitation_id}",
        )
      end
    end
  end
end
