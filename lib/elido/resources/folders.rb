# frozen_string_literal: true

module Elido
  module Resources
    # Mirrors the Python SDK's `client.folders.*` namespace.
    #
    # NOTE: the `/v1/workspaces/{ws}/folders` endpoint family is not
    # (yet) in the published OpenAPI spec; shapes may tighten later.
    class Folders
      def initialize(client)
        @client = client
      end

      def list(workspace_id:)
        @client.get("/v1/workspaces/#{workspace_id}/folders")
      end

      def create(workspace_id:, name:, color: nil, idempotency_key: nil)
        body = { name: name }
        body[:color] = color if color
        @client.post(
          "/v1/workspaces/#{workspace_id}/folders",
          body: body,
          idempotency_key: idempotency_key,
        )
      end

      def update(workspace_id:, folder_id:, **patch)
        @client.patch(
          "/v1/workspaces/#{workspace_id}/folders/#{folder_id}",
          body: patch,
        )
      end

      def delete(workspace_id:, folder_id:)
        @client.delete("/v1/workspaces/#{workspace_id}/folders/#{folder_id}")
      end
    end
  end
end
