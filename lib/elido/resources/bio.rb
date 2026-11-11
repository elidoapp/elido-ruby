# frozen_string_literal: true

module Elido
  module Resources
    # "Link-in-bio" pages — micro-sites a creator hosts on
    # bio.elido.me/{username}. The renderer is its own service
    # but CRUD goes through the main API.
    class Bio
      def initialize(client)
        @client = client
      end

      def list(workspace_id:)
        @client.get("/v1/workspaces/#{workspace_id}/bio")
      end

      def create(workspace_id:, username:, idempotency_key: nil, **extra)
        @client.post(
          "/v1/workspaces/#{workspace_id}/bio",
          body: { username: username, **extra },
          idempotency_key: idempotency_key,
        )
      end

      def get(workspace_id:, bio_id:)
        @client.get("/v1/workspaces/#{workspace_id}/bio/#{bio_id}")
      end

      def update(workspace_id:, bio_id:, **patch)
        @client.patch(
          "/v1/workspaces/#{workspace_id}/bio/#{bio_id}",
          body: patch,
        )
      end

      def delete(workspace_id:, bio_id:)
        @client.delete("/v1/workspaces/#{workspace_id}/bio/#{bio_id}")
      end

      def list_links(workspace_id:, bio_id:)
        @client.get(
          "/v1/workspaces/#{workspace_id}/bio/#{bio_id}/links",
        )
      end

      def add_link(workspace_id:, bio_id:, url:, idempotency_key: nil, **extra)
        @client.post(
          "/v1/workspaces/#{workspace_id}/bio/#{bio_id}/links",
          body: { url: url, **extra },
          idempotency_key: idempotency_key,
        )
      end

      def update_link(workspace_id:, bio_id:, link_id:, **patch)
        @client.patch(
          "/v1/workspaces/#{workspace_id}/bio/#{bio_id}/links/#{link_id}",
          body: patch,
        )
      end

      def remove_link(workspace_id:, bio_id:, link_id:)
        @client.delete(
          "/v1/workspaces/#{workspace_id}/bio/#{bio_id}/links/#{link_id}",
        )
      end

      # Aggregated click positions for the heatmap overlay in the
      # dashboard. Cached server-side; safe to poll.
      def heatmap(workspace_id:, bio_id:, from: nil, to: nil)
        @client.get(
          "/v1/workspaces/#{workspace_id}/bio/#{bio_id}/heatmap",
          params: { from: from, to: to },
        )
      end
    end
  end
end
