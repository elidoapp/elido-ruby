# frozen_string_literal: true

module Elido
  module Resources
    class Compliance
      def initialize(client)
        @client = client
      end

      def get(workspace_id:)
        @client.get("/v1/workspaces/#{workspace_id}/compliance")
      end

      def update(workspace_id:, **body)
        @client.put("/v1/workspaces/#{workspace_id}/compliance", body: body)
      end

      # SOC 2 / HIPAA evidence snapshot — JSON view of posture +
      # access controls + audit volume + SSO/SCIM bindings.
      def evidence(workspace_id:)
        @client.get(
          "/v1/workspaces/#{workspace_id}/compliance/evidence",
        )
      end

      # URL of the streaming ZIP bundle. Caller fetches with its own
      # auth headers so the response can stream straight to disk.
      def evidence_bundle_url(workspace_id:)
        "#{@client.base_url}/v1/workspaces/#{workspace_id}/compliance/evidence.zip"
      end
    end
  end
end
