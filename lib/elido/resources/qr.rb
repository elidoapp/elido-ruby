# frozen_string_literal: true

module Elido
  module Resources
    # The QR endpoints return binary payloads (PNG / SVG / PDF)
    # — the client passes the parsed body straight back as a String.
    # For PNG / PDF the response body is binary; treat it as raw bytes.
    class Qr
      def initialize(client)
        @client = client
      end

      # POST /v1/qr/generate. Body fields mirror the OpenAPI schema —
      # `data:` (URL or arbitrary text), `format:` ("png" / "svg" /
      # "pdf"), optional `style:` block with colors / logo / etc.
      def generate(data:, format: "png", idempotency_key: nil, **style)
        @client.post(
          "/v1/qr/generate",
          body: { data: data, format: format, **style },
          idempotency_key: idempotency_key,
          base: :qr,
        )
      end

      # POST /v1/qr/gs1 — GS1-Digital-Link variant used for retail /
      # pharma compliance. Not on every plan; 403 if disabled.
      def gs1(gtin:, link:, idempotency_key: nil, **extra)
        @client.post(
          "/v1/qr/gs1",
          body: { gtin: gtin, link: link, **extra },
          idempotency_key: idempotency_key,
          base: :qr,
        )
      end
    end
  end
end
