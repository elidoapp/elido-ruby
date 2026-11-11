# frozen_string_literal: true

module Elido
  # Bumped in lockstep with the Python / Go / TypeScript SDKs. The
  # OpenAPI spec churns more often than the SDK does — we only cut a
  # new gem when a hand-written method changes its argument shape, a
  # new resource is added, or an error class is renamed.
  VERSION = "0.1.0"
end
