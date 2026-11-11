# frozen_string_literal: true

module Elido
  module Resources
    # Workspace member CRUD. Read endpoints are also reachable via
    # Workspaces#members(id); this namespace adds role updates and
    # removal which aren't available on the workspaces resource.
    class Members
      def initialize(client)
        @client = client
      end

      def list(workspace_id:)
        @client.get("/v1/workspaces/#{workspace_id}/members")
      end

      def update(workspace_id:, user_id:, role:)
        @client.patch(
          "/v1/workspaces/#{workspace_id}/members/#{user_id}",
          body: { role: role },
        )
      end

      def remove(workspace_id:, user_id:)
        @client.delete(
          "/v1/workspaces/#{workspace_id}/members/#{user_id}",
        )
      end
    end
  end
end
