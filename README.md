# elido — Ruby SDK

Sync Ruby client for the [Elido](https://elido.app) URL-shortener API.
Hand-written against Elido's public OpenAPI spec (<https://elido.app/openapi.json>);
the surface mirrors `@elido/sdk` (TypeScript), `elido-sdk` (Python) and `github.com/elidoapp/elido-go` (Go).

## Install

```ruby
# Gemfile
gem "elido", "~> 0.1"
```

```bash
bundle install
# or directly:
gem install elido
```

Requires Ruby 3.1+.

## Quick start

```ruby
require "elido"

client = Elido::Client.new(
  api_key: ENV.fetch("ELIDO_API_KEY"),
  base_url: "https://api.elido.app",  # default
)

# Who am I?
me = client.users.me
puts me["email"]

# Create a link
link = client.links.create(
  workspace_id: 42,
  original_url: "https://example.com/landing",
  slug: "spring-2026",
  tags: ["promo"],
)
puts link["slug"]

# Paginate everything
client.links.each(workspace_id: 42) do |link|
  puts link["slug"]
end

# Analytics
top = client.analytics.top_links(
  workspace_id: 42,
  from: "2026-04-01",
  to: "2026-05-01",
  limit: 20,
)
top["items"].each { |row| puts "#{row['link_id']}: #{row['count']}" }
```

### Module-level configuration

```ruby
Elido.configure do |c|
  c.api_key  = ENV.fetch("ELIDO_API_KEY")
  c.base_url = "https://api.elido.app"
end

Elido.default_client.workspaces.list
```

## Auth

In order of precedence (first non-nil wins):

| Constructor arg        | Header sent               | Use case            |
| ---------------------- | ------------------------- | ------------------- |
| `api_key: "elido_..."` | `Authorization: Bearer …` | Production scripts  |
| `cookie: "..."`        | `Cookie: …`               | Server-side proxies |

API keys come from the dashboard at `/dashboard/api-keys`; the plain
`elk_...` string is shown once on creation and stored hashed. Rotate
with `client.api_keys.create(...)` + `client.api_keys.revoke(...)`.

## Idempotency

All `POST` methods accept an optional `idempotency_key:`. If you omit
it the SDK auto-generates a UUID4 and sends it as `Idempotency-Key`,
so a network retry won't double-create. Pass your own when you want
deterministic retries:

```ruby
client.links.create(
  workspace_id: 42,
  original_url: "https://example.com",
  idempotency_key: "order-12345",
)
```

## Errors

| Status    | Exception class              | Extras                                  |
| --------- | ---------------------------- | --------------------------------------- |
| 401       | `Elido::AuthenticationError` | —                                       |
| 403       | `Elido::PermissionError`     | —                                       |
| 404       | `Elido::NotFoundError`       | —                                       |
| 409       | `Elido::ConflictError`       | —                                       |
| 422       | `Elido::ValidationError`     | `#errors` — field → \[messages] hash    |
| 429       | `Elido::RateLimitError`      | `#retry_after` — seconds (Int) or nil   |
| 5xx       | `Elido::ServerError`         | —                                       |
| other 4xx | `Elido::ApiError`            | —                                       |
| transport | `Elido::ConnectionError`     | `#cause_error` — the underlying Faraday |

Every API exception carries `#status`, `#body`, `#request_id`
(propagated from the server's `X-Request-ID` header). The SDK never
retries automatically; bring your own backoff for `RateLimitError`
and `ServerError`.

## Multi-host setups

When you front Elido with separate hostnames per backend service
(the self-host template does), pass URLs explicitly:

```ruby
client = Elido::Client.new(
  api_key: "elk_...",
  base_url:           "https://api.elido.app",
  analytics_base_url: "https://analytics.elido.app",
  billing_base_url:   "https://billing.elido.app",
  qr_base_url:        "https://qr.elido.app",
)
```

Anything not set falls back to `base_url`.

## Resource parity

The SDK covers the hand-curated surface that the Python SDK also
covers — the full OpenAPI spec has ~80 endpoints, but the typical
caller only needs:

| Namespace            | Endpoints                                                                                                      |
| -------------------- | -------------------------------------------------------------------------------------------------------------- |
| `client.users`       | `me`, `update_my_timezone`                                                                                     |
| `client.workspaces`  | `list`, `create`, `get`, `update`, `delete`, `members`                                                         |
| `client.links`       | `list`, `each`, `create`, `get`, `update`, `delete`, `bulk_create`, `bulk_mutate`, `suggest_slug`              |
| `client.folders`     | `list`, `create`, `update`, `delete`                                                                           |
| `client.api_keys`    | `list`, `create`, `revoke`                                                                                     |
| `client.invitations` | `list`, `create`, `revoke`                                                                                     |
| `client.analytics`   | `timeseries`, `top_links`, `summary`, `funnel`, `cohorts`, `heatmap`, `recent_clicks`, `ltv`                   |
| `client.billing`     | `plans`, `subscription`, `checkout`, `cancel`                                                                  |
| `client.pixels`      | `get`, `upsert`, `delete`                                                                                      |
| `client.compliance`  | `get`, `update`, `evidence`, `evidence_bundle_url`                                                             |
| `client.domains`     | `list`, `create`, `app_links`                                                                                  |
| `client.qr`          | `generate`, `gs1`                                                                                              |
| `client.campaigns`   | `list`, `create`, `get`, `update`, `delete`, `links`                                                           |
| `client.bio`         | `list`, `create`, `get`, `update`, `delete`, `list_links`, `add_link`, `update_link`, `remove_link`, `heatmap` |
| `client.members`     | `list`, `update`, `remove`                                                                                     |
| `client.webhooks`    | `list`, `create`, `get`, `update`, `delete`, `rotate_secret`                                                   |

Endpoints outside this list (SSO discovery, SCIM provisioning, AI
resolve, scheduled reports, conversions, broken-links scanner, etc.)
are reachable via `client.get(path, params: …)` and the other verb
helpers — escape-hatch onto the same auth + error pipeline.

## Pagination

`client.links.each(workspace_id: id)` walks all pages of the
collection — handles both the `items/limit/offset` shape and the
`items/next_cursor` shape. Without a
block, returns an `Enumerator` so you can `.lazy.map { … }`.

```ruby
client.links.each(workspace_id: 42).lazy.map { |l| l["slug"] }.first(50)
```

## Versioning

This SDK is hand-written, not generated. The wire JSON is the
contract — adding or renaming a server-side field never breaks
callers as long as the JSON shape stays. Breaking SDK changes (a
method renaming, an error class moving) bump the minor.

## Development

```bash
bundle install
bundle exec rspec
```

## Links

- Documentation: <https://elido.app/docs>
- Issues: <https://github.com/elidoapp/elido-ruby/issues>
- Changelog: [CHANGELOG.md](./CHANGELOG.md)

## License

[MIT](./LICENSE) (c) Elido. The Elido service itself is a separate, hosted
product; this repository contains only the client library.
