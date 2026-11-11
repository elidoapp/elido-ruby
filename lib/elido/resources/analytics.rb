# frozen_string_literal: true

module Elido
  module Resources
    # Read-only reporting over ClickHouse. All endpoints take
    # `from:` / `to:` as ISO-8601 date strings; the server treats
    # them as inclusive of both ends, UTC-normalised. `link_id:`
    # narrows every endpoint to a single short URL.
    class Analytics
      def initialize(client)
        @client = client
      end

      def timeseries(workspace_id:, from:, to:, interval: nil, link_id: nil)
        @client.get(
          "/v1/analytics/workspaces/#{workspace_id}/timeseries",
          params: { from: from, to: to, interval: interval, link_id: link_id },
          base: :analytics,
        )
      end

      def top_links(workspace_id:, from:, to:, limit: nil)
        @client.get(
          "/v1/analytics/workspaces/#{workspace_id}/links/top",
          params: { from: from, to: to, limit: limit },
          base: :analytics,
        )
      end

      def summary(workspace_id:, from:, to:, link_id: nil)
        @client.get(
          "/v1/analytics/workspaces/#{workspace_id}/summary",
          params: { from: from, to: to, link_id: link_id },
          base: :analytics,
        )
      end

      def funnel(workspace_id:, from:, to:, **filters)
        @client.get(
          "/v1/analytics/workspaces/#{workspace_id}/funnel",
          params: { from: from, to: to, **filters },
          base: :analytics,
        )
      end

      def cohorts(workspace_id:, from:, to:, **filters)
        @client.get(
          "/v1/analytics/workspaces/#{workspace_id}/cohorts",
          params: { from: from, to: to, **filters },
          base: :analytics,
        )
      end

      def heatmap(workspace_id:, from:, to:, **filters)
        @client.get(
          "/v1/analytics/workspaces/#{workspace_id}/heatmap",
          params: { from: from, to: to, **filters },
          base: :analytics,
        )
      end

      def recent_clicks(workspace_id:, limit: nil)
        @client.get(
          "/v1/analytics/workspaces/#{workspace_id}/clicks/recent",
          params: { limit: limit },
          base: :analytics,
        )
      end

      # Lifetime-value report. `currency:` is an ISO currency code
      # (default USD); cohorts with no conversions in that currency
      # show revenue_cents == 0.
      def ltv(workspace_id:, from:, to:, currency: nil, link_id: nil)
        @client.get(
          "/v1/analytics/workspaces/#{workspace_id}/ltv",
          params: { from: from, to: to, currency: currency, link_id: link_id },
          base: :analytics,
        )
      end
    end
  end
end
