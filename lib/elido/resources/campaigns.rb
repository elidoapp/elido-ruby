# frozen_string_literal: true

module Elido
  module Resources
    # UTM campaign grouping. A campaign is a label + colour + date
    # window that scopes a bag of links for reporting.
    class Campaigns
      def initialize(client)
        @client = client
      end

      def list(workspace_id:)
        @client.get("/v1/workspaces/#{workspace_id}/campaigns")
      end

      def create(workspace_id:, name:, idempotency_key: nil, **extra)
        @client.post(
          "/v1/workspaces/#{workspace_id}/campaigns",
          body: { name: name, **extra },
          idempotency_key: idempotency_key,
        )
      end

      def get(workspace_id:, campaign_id:)
        @client.get(
          "/v1/workspaces/#{workspace_id}/campaigns/#{campaign_id}",
        )
      end

      def update(workspace_id:, campaign_id:, **patch)
        @client.patch(
          "/v1/workspaces/#{workspace_id}/campaigns/#{campaign_id}",
          body: patch,
        )
      end

      def delete(workspace_id:, campaign_id:)
        @client.delete(
          "/v1/workspaces/#{workspace_id}/campaigns/#{campaign_id}",
        )
      end

      def links(workspace_id:, campaign_id:)
        @client.get(
          "/v1/workspaces/#{workspace_id}/campaigns/#{campaign_id}/links",
        )
      end
    end
  end
end
