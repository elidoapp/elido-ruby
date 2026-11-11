# frozen_string_literal: true

module Elido
  module Resources
    # Marketing pixels (Facebook/GA4/Pinterest IDs) attached to a
    # workspace. The dashboard injects them into bio pages + UTM
    # redirects.
    class Pixels
      def initialize(client)
        @client = client
      end

      def get(workspace_id:)
        @client.get("/v1/workspaces/#{workspace_id}/pixels")
      end

      def upsert(workspace_id:, **body)
        @client.put("/v1/workspaces/#{workspace_id}/pixels", body: body)
      end

      def delete(workspace_id:)
        @client.delete("/v1/workspaces/#{workspace_id}/pixels")
      end
    end
  end
end
