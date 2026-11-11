# frozen_string_literal: true

require "spec_helper"

RSpec.describe Elido::Resources::Links do
  let(:client) { build_client }

  describe "#list" do
    it "GETs the workspace-scoped collection" do
      stub_request(:get, "https://api.test/v1/workspaces/7/links")
        .to_return(json_response({ "items" => [{ "id" => 1, "slug" => "abc" }], "limit" => 20, "offset" => 0 }))

      out = client.links.list(workspace_id: 7)
      expect(out["items"].first["slug"]).to eq("abc")
    end

    it "passes filters through" do
      stub_request(:get, "https://api.test/v1/workspaces/7/links")
        .with(query: { "q" => "marketing", "limit" => "10" })
        .to_return(json_response({ "items" => [] }))

      client.links.list(workspace_id: 7, q: "marketing", limit: 10)
    end
  end

  describe "#create" do
    it "POSTs JSON with snake_case body fields" do
      stub_request(:post, "https://api.test/v1/workspaces/7/links")
        .with(body: hash_including("original_url" => "https://example.com", "slug" => "abc"))
        .to_return(json_response({ "id" => 42, "slug" => "abc" }))

      out = client.links.create(workspace_id: 7,
                                 original_url: "https://example.com",
                                 slug: "abc",
                                 tags: %w[spring 2026])
      expect(out["id"]).to eq(42)
    end

    it "drops nil optional fields from the body" do
      stub = stub_request(:post, "https://api.test/v1/workspaces/7/links")
        .to_return(lambda do |req|
          body = JSON.parse(req.body)
          expect(body.keys).to contain_exactly("original_url")
          { status: 200, body: "{}", headers: { "Content-Type" => "application/json" } }
        end)

      client.links.create(workspace_id: 7, original_url: "https://example.com")
      expect(stub).to have_been_requested
    end
  end

  describe "#get" do
    it "fetches a single link by id" do
      stub_request(:get, "https://api.test/v1/workspaces/7/links/42")
        .to_return(json_response({ "id" => 42, "slug" => "abc" }))
      expect(client.links.get(workspace_id: 7, link_id: 42)["slug"]).to eq("abc")
    end
  end

  describe "#update" do
    it "PATCHes with the supplied fields" do
      stub_request(:patch, "https://api.test/v1/workspaces/7/links/42")
        .with(body: { "title" => "Renamed" })
        .to_return(json_response({ "id" => 42, "title" => "Renamed" }))

      client.links.update(workspace_id: 7, link_id: 42, title: "Renamed")
    end
  end

  describe "#delete" do
    it "DELETEs the resource and returns nil on 204" do
      stub_request(:delete, "https://api.test/v1/workspaces/7/links/42")
        .to_return(status: 204, body: "")
      expect(client.links.delete(workspace_id: 7, link_id: 42)).to be_nil
    end
  end

  describe "#bulk_create" do
    it "POSTs the wrapper body with domain_id + links array" do
      stub_request(:post, "https://api.test/v1/workspaces/7/links/bulk")
        .with(body: { "domain_id" => 1, "links" => [{ "original_url" => "https://a.test" }] })
        .to_return(json_response({ "created" => 1 }))

      client.links.bulk_create(workspace_id: 7, domain_id: 1,
                                links: [{ original_url: "https://a.test" }])
    end
  end

  describe "#each (pagination)" do
    it "walks all pages using offset" do
      stub_request(:get, "https://api.test/v1/workspaces/7/links")
        .with(query: { "limit" => "2" })
        .to_return(json_response({ "items" => [{ "id" => 1 }, { "id" => 2 }] }))
      stub_request(:get, "https://api.test/v1/workspaces/7/links")
        .with(query: { "limit" => "2", "offset" => "2" })
        .to_return(json_response({ "items" => [{ "id" => 3 }] }))

      ids = []
      client.links.each(workspace_id: 7, limit: 2) { |link| ids << link["id"] }
      expect(ids).to eq([1, 2, 3])
    end

    it "follows next_cursor when the response has one" do
      stub_request(:get, "https://api.test/v1/workspaces/7/links")
        .with(query: { "limit" => "100" })
        .to_return(json_response({ "items" => [{ "id" => 1 }], "next_cursor" => "c1" }))
      stub_request(:get, "https://api.test/v1/workspaces/7/links")
        .with(query: hash_including("cursor" => "c1"))
        .to_return(json_response({ "items" => [{ "id" => 2 }], "next_cursor" => nil }))

      ids = client.links.each(workspace_id: 7).map { |l| l["id"] }
      expect(ids).to eq([1, 2])
    end

    it "returns an Enumerator when no block is given" do
      expect(client.links.each(workspace_id: 7)).to be_a(Enumerator)
    end
  end

  describe "#suggest_slug" do
    it "POSTs to the suggest-slug endpoint" do
      stub_request(:post, "https://api.test/v1/workspaces/7/links/suggest-slug")
        .with(body: { "original_url" => "https://example.com" })
        .to_return(json_response({ "slug" => "example-abc" }))

      expect(client.links.suggest_slug(workspace_id: 7, original_url: "https://example.com")["slug"])
        .to eq("example-abc")
    end
  end
end
