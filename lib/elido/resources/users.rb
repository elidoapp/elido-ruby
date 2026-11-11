# frozen_string_literal: true

module Elido
  module Resources
    # `/v1/me` and friends. Resolves the authenticated principal —
    # API key, session cookie, or X-Dev-User-ID.
    class Users
      def initialize(client)
        @client = client
      end

      # Returns the authenticated user. Raises AuthenticationError(401)
      # if no credential is set / the token is rejected.
      def me
        @client.get("/v1/me")
      end

      # PATCH /v1/me/timezone. `timezone` is an IANA zone name
      # ("Europe/Berlin"); the server validates via Go's time.LoadLocation.
      def update_my_timezone(timezone:)
        @client.patch("/v1/me/timezone", body: { timezone: timezone })
      end
    end
  end
end
