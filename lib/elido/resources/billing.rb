# frozen_string_literal: true

module Elido
  module Resources
    class Billing
      def initialize(client)
        @client = client
      end

      def plans
        @client.get("/v1/billing/plans", base: :billing)
      end

      def subscription(workspace_id:)
        @client.get(
          "/v1/billing/workspaces/#{workspace_id}/subscription",
          base: :billing,
        )
      end

      def checkout(workspace_id:, plan_id:, idempotency_key: nil)
        @client.post(
          "/v1/billing/workspaces/#{workspace_id}/checkout",
          body: { plan_id: plan_id },
          idempotency_key: idempotency_key,
          base: :billing,
        )
      end

      def cancel(workspace_id:, idempotency_key: nil)
        @client.post(
          "/v1/billing/workspaces/#{workspace_id}/subscription/cancel",
          idempotency_key: idempotency_key,
          base: :billing,
        )
      end
    end
  end
end
