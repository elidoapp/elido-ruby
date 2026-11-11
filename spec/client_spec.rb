# frozen_string_literal: true

require "spec_helper"

RSpec.describe Elido::Client do
  describe "auth header selection" do
    it "uses Bearer when api_key is set" do
      client = build_client
      stub = stub_request(:get, "https://api.test/v1/me")
        .with(headers: { "Authorization" => "Bearer elk_test_key" })
        .to_return(json_response({ "id" => 1, "email" => "a@b.test" }))

      client.users.me
      expect(stub).to have_been_requested
    end

    it "uses Cookie when only a cookie is set" do
      client = Elido::Client.new(base_url: ClientHelpers::TEST_HOST, cookie: "ory_session=abc")
      stub = stub_request(:get, "https://api.test/v1/me")
        .with(headers: { "Cookie" => "ory_session=abc" })
        .to_return(json_response({ "id" => 1 }))

      client.users.me
      expect(stub).to have_been_requested
    end

    it "uses X-Dev-User-ID when only dev_user_id is set" do
      client = Elido::Client.new(base_url: ClientHelpers::TEST_HOST, dev_user_id: 7)
      stub = stub_request(:get, "https://api.test/v1/me")
        .with(headers: { "X-Dev-User-ID" => "7" })
        .to_return(json_response({ "id" => 7 }))

      client.users.me
      expect(stub).to have_been_requested
    end

    it "sends a User-Agent on every request" do
      client = build_client
      stub = stub_request(:get, "https://api.test/v1/workspaces")
        .with(headers: { "User-Agent" => /elido-ruby/ })
        .to_return(json_response({ "items" => [] }))

      client.workspaces.list
      expect(stub).to have_been_requested
    end
  end

  describe "idempotency keys" do
    it "auto-generates an Idempotency-Key on POSTs" do
      client = build_client
      key_seen = nil
      stub = stub_request(:post, "https://api.test/v1/workspaces")
        .to_return(lambda do |req|
          key_seen = req.headers["Idempotency-Key"]
          { status: 200, body: '{"id":1}', headers: { "Content-Type" => "application/json" } }
        end)

      client.workspaces.create(name: "Acme", slug: "acme")
      expect(stub).to have_been_requested
      expect(key_seen).to match(/\A[0-9a-f-]{36}\z/)
    end

    it "respects a caller-supplied Idempotency-Key" do
      client = build_client
      stub = stub_request(:post, "https://api.test/v1/workspaces")
        .with(headers: { "Idempotency-Key" => "user-supplied-123" })
        .to_return(json_response({ "id" => 1 }))

      client.workspaces.create(name: "Acme", slug: "acme", idempotency_key: "user-supplied-123")
      expect(stub).to have_been_requested
    end

    it "does NOT send Idempotency-Key on GET / PATCH / DELETE" do
      client = build_client
      stub_request(:get, "https://api.test/v1/workspaces").to_return(json_response({}))
      client.workspaces.list

      expect(
        a_request(:get, "https://api.test/v1/workspaces").with do |req|
          !req.headers.key?("Idempotency-Key")
        end,
      ).to have_been_made.once
    end
  end

  describe "error mapping" do
    let(:client) { build_client }

    it "raises AuthenticationError on 401" do
      stub_request(:get, "https://api.test/v1/me")
        .to_return(error_response(401, { "error" => "missing token" },
                                  headers: { "X-Request-ID" => "req_abc" }))

      expect { client.users.me }.to raise_error(Elido::AuthenticationError) do |err|
        expect(err.status).to eq(401)
        expect(err.request_id).to eq("req_abc")
        expect(err.message).to include("missing token")
        expect(err.to_s).to include("req_abc")
      end
    end

    it "raises PermissionError on 403" do
      stub_request(:get, "https://api.test/v1/me")
        .to_return(error_response(403, { "error" => "forbidden" }))
      expect { client.users.me }.to raise_error(Elido::PermissionError)
    end

    it "raises NotFoundError on 404" do
      stub_request(:get, "https://api.test/v1/workspaces/99")
        .to_return(error_response(404, { "error" => "not found" }))
      expect { client.workspaces.get(99) }.to raise_error(Elido::NotFoundError) do |err|
        expect(err.message).to include("not found")
      end
    end

    it "raises ConflictError on 409" do
      stub_request(:post, "https://api.test/v1/workspaces")
        .to_return(error_response(409, { "error" => "slug taken" }))
      expect { client.workspaces.create(name: "X", slug: "x") }
        .to raise_error(Elido::ConflictError)
    end

    it "raises ValidationError on 422 with field errors" do
      stub_request(:post, "https://api.test/v1/workspaces")
        .to_return(error_response(422, {
          "error" => "validation failed",
          "errors" => { "slug" => ["already taken"] },
        }))

      expect { client.workspaces.create(name: "X", slug: "x") }
        .to raise_error(Elido::ValidationError) do |err|
          expect(err.errors).to eq({ "slug" => ["already taken"] })
        end
    end

    it "raises RateLimitError on 429 with retry_after" do
      stub_request(:get, "https://api.test/v1/workspaces")
        .to_return(error_response(429, { "error" => "slow down" },
                                  headers: { "Retry-After" => "5" }))

      expect { client.workspaces.list }.to raise_error(Elido::RateLimitError) do |err|
        expect(err.retry_after).to eq(5)
      end
    end

    it "raises ServerError on 5xx" do
      stub_request(:get, "https://api.test/v1/workspaces")
        .to_return(error_response(503, { "error" => "upstream broken" }))
      expect { client.workspaces.list }.to raise_error(Elido::ServerError)
    end

    it "raises generic ApiError on unmapped 4xx" do
      stub_request(:get, "https://api.test/v1/workspaces")
        .to_return(error_response(418, { "error" => "teapot" }))
      expect { client.workspaces.list }.to raise_error(Elido::ApiError)
    end

    it "raises ConnectionError when Faraday can't reach the host" do
      stub_request(:get, "https://api.test/v1/workspaces").to_raise(Faraday::ConnectionFailed.new("dns"))
      expect { client.workspaces.list }.to raise_error(Elido::ConnectionError) do |err|
        expect(err.cause_error).to be_a(Faraday::ConnectionFailed)
      end
    end
  end

  describe "response decoding" do
    let(:client) { build_client }

    it "returns nil for 204" do
      stub_request(:delete, "https://api.test/v1/workspaces/1/links/2")
        .to_return(status: 204, body: "")
      expect(client.links.delete(workspace_id: 1, link_id: 2)).to be_nil
    end

    it "parses JSON when content-type is application/json" do
      stub_request(:get, "https://api.test/v1/workspaces")
        .to_return(json_response({ "items" => [{ "id" => 1 }] }))
      expect(client.workspaces.list).to eq({ "items" => [{ "id" => 1 }] })
    end

    it "drops nil params from the query string" do
      stub_request(:get, "https://api.test/v1/workspaces/7/links")
        .with(query: { "limit" => "20" })
        .to_return(json_response({ "items" => [], "limit" => 20, "offset" => 0 }))

      client.links.list(workspace_id: 7, limit: 20, offset: nil)
    end

    it "comma-joins Array params (tags)" do
      stub_request(:get, "https://api.test/v1/workspaces/7/links")
        .with(query: { "tags" => "a,b", "folder" => "42" })
        .to_return(json_response({ "items" => [] }))

      client.links.list(workspace_id: 7, tags: %w[a b], folder: 42)
    end
  end

  describe "module-level configure" do
    it "lazily builds a client from configuration" do
      stub_request(:get, "https://api.test/v1/me")
        .to_return(json_response({ "id" => 1, "email" => "a@b.test" }))

      Elido.configure do |c|
        c.api_key = "elk_test_key"
        c.base_url = "https://api.test"
      end

      out = Elido.default_client.users.me
      expect(out["email"]).to eq("a@b.test")
    end

    it "rebuilds the default client when configure is called again" do
      Elido.configure { |c| c.api_key = "one" }
      first = Elido.default_client
      Elido.configure { |c| c.api_key = "two" }
      expect(Elido.default_client).not_to equal(first)
    end
  end
end
