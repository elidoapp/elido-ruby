# frozen_string_literal: true

require "elido"
require "webmock/rspec"
require "json"

WebMock.disable_net_connect!(allow_localhost: false)

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    Elido.reset_default_client!
    # Reset configuration between tests so configure-based examples
    # don't leak state into each other.
    Elido.instance_variable_set(:@configuration, nil)
  end
end

# Shared helper — most specs want a client wired to a deterministic
# host so we can stub absolute URLs.
module ClientHelpers
  TEST_HOST = "https://api.test"

  def build_client(**overrides)
    Elido::Client.new(
      api_key: "elk_test_key",
      base_url: TEST_HOST,
      **overrides,
    )
  end

  def json_response(body, headers: {})
    {
      status: 200,
      body: JSON.generate(body),
      headers: { "Content-Type" => "application/json" }.merge(headers),
    }
  end

  def error_response(status, body, headers: {})
    {
      status: status,
      body: body.is_a?(String) ? body : JSON.generate(body),
      headers: { "Content-Type" => "application/json" }.merge(headers),
    }
  end
end

RSpec.configure do |config|
  config.include ClientHelpers
end
