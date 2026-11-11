# frozen_string_literal: true

require_relative "lib/elido/version"

Gem::Specification.new do |spec|
  spec.name        = "elido"
  spec.version     = Elido::VERSION
  spec.authors     = ["Elido"]
  spec.email       = ["engineering@elido.app"]

  spec.summary     = "Ruby SDK for the Elido URL shortener API."
  spec.description = "Hand-rolled, dependency-light Ruby client for the Elido " \
                     "API (links, QR, analytics, billing, bio, campaigns, webhooks). " \
                     "Mirrors the Python / Go / TypeScript SDK surfaces."
  spec.homepage    = "https://elido.app/docs"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/elidoapp/elido-ruby"
  spec.metadata["bug_tracker_uri"] = "https://github.com/elidoapp/elido-ruby/issues"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["documentation_uri"] = "https://elido.app/docs"
  spec.metadata["changelog_uri"]   = "https://github.com/elidoapp/elido-ruby/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*.rb",
    "README.md",
    "LICENSE",
    "CHANGELOG.md",
    "elido.gemspec",
  ]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", ">= 2.7", "< 3.0"
  spec.add_dependency "faraday-net_http", ">= 3.0"

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.19"
end
