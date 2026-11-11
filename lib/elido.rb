# frozen_string_literal: true

# Ruby SDK for the Elido URL shortener API.
#
# Quick start:
#
#   require "elido"
#
#   client = Elido::Client.new(api_key: "elk_...", base_url: "https://api.elido.app")
#   me = client.users.me
#   client.links.create(workspace_id: 1, original_url: "https://example.com", slug: "abc")
#
# Or, module-level config:
#
#   Elido.configure do |c|
#     c.api_key = ENV.fetch("ELIDO_API_KEY")
#   end
#   Elido.default_client.workspaces.list
#
# The client is sync-only on purpose — this is a scripting / server-side
# SDK and most users want one round-trip per call. Async is on the caller.
require_relative "elido/version"
require_relative "elido/error"
require_relative "elido/pagination"
require_relative "elido/client"

module Elido
end
