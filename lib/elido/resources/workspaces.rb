# frozen_string_literal: true

module Elido
  module Resources
    class Workspaces
      def initialize(client)
        @client = client
      end

      def list
        @client.get("/v1/workspaces")
      end

      def create(name:, slug:, idempotency_key: nil)
        @client.post(
          "/v1/workspaces",
          body: { name: name, slug: slug },
          idempotency_key: idempotency_key,
        )
      end

      def get(workspace_id)
        @client.get("/v1/workspaces/#{workspace_id}")
      end

      def update(workspace_id, **patch)
        @client.patch("/v1/workspaces/#{workspace_id}", body: patch)
      end

      def delete(workspace_id)
        @client.delete("/v1/workspaces/#{workspace_id}")
      end

      # Members listing is also available via Client#members.list — both
      # paths hit the same endpoint and exist for DX symmetry.
      def members(workspace_id)
        @client.get("/v1/workspaces/#{workspace_id}/members")
      end
    end
  end
end
