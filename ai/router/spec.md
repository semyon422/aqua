# AI Router

## Goal

Provide a standalone multi-subscription OpenAI-compatible router: one server that authenticates named users, routes Chat Completions requests across several upstream subscriptions (ChatGPT/Codex OAuth, GLM Coding Plan, local llama.cpp), steers traffic away from subscriptions whose 5-hour or weekly limits are nearly exhausted, supports custom model aliases with ordered fallback chains, and reports usage statistics — without depending on application-specific code beyond the existing `aqua/ai` clients.

## User Experience

- Operators add subscriptions in a web admin panel: OpenAI subscriptions (each with its own OAuth login), GLM Coding Plan keys, and local llama.cpp endpoints. Each subscription lists the models it serves, may permanently redirect model names upstream, and may define steering thresholds for its 5-hour and weekly limit windows.
- Operators create users in the admin panel, receive a generated API key shown once, and grant each user access to specific public models.
- Operators define custom model names with ordered fallback chains, for example `lite → glm-5.3-flash → gpt-6-luna`: requests prefer the first chain entry whose subscriptions are available and fall through to later entries when earlier ones are depleted.
- Clients point any OpenAI Chat Completions consumer at `POST /v1/chat/completions` (streaming and non-streaming) with their router key and see only the models they were granted in `GET /v1/models`.
- Subscriptions are consumed in priority order: traffic goes to the highest-priority subscription that serves the model and is not past its thresholds. When it crosses a threshold, new requests move to the next subscription; when its window resets, it becomes primary again.
- Upstream quota, authentication, and transport failures before any output transparently move the request to the next candidate; the client sees one clean response.
- The admin panel shows usage statistics like the existing OpenAI proxy dashboard: total spend, per-user, per-model, and per-subscription totals with hourly charts, request counts, errors, and estimated counts.
- The admin panel shows live subscription state: current 5-hour and weekly window fill, data source and freshness, reset times, and cooldown status.

## Architecture Decisions

- The router is a standalone Lua server on `web.http.Server` with `web.luasocket.CosocketScheduler`, mirroring `aqua/ai/openai/proxy.lua` and `aqua/ai/zai/proxy.lua`. It binds loopback by default and is exposed publicly through Nginx, like the existing proxies. It supersedes them operationally when stable; they remain untouched.
- Package layout and responsibilities:
  - `proxy.lua` — standalone entrypoint (`serve`, subscription `login` commands), loads the ignored `userdata/ai_router.lua` config.
  - `ai.router.Server` — HTTP handling: client authentication, request limits, `/v1/*` endpoints, `/admin/*` endpoints, admin sessions.
  - `ai.router.Catalog` builds and deep-validates the routing state from repository rows (kind-specific config shapes, thresholds, redirect sources, concrete chain entries, alias nesting and shadowing). Admin saves validate through it before persisting; the runtime asserts a clean build. Default `usage_source` is `upstream` for openai and zai subscriptions and `local` for `openai_compat`.
  - `ai.router.Router` — model resolution and subscription selection (pure logic over in-memory state; injected clock and window data; unit-testable without sockets).
  - `ai.router.UsageMonitor` — polls upstream usage endpoints and maintains per-subscription window fill state; runs as a scheduler task.
  - `ai.router.Provider` declares the canonical provider contract (assistant message and usage shapes, streaming delta shapes) and shared normalization helpers; `OpenAIProvider`, `ZaiProvider`, and `CompatProvider` implement it.
  - `ai.router.storage.RouterDatabase` plus repos (`UsersRepo`, `SubscriptionsRepo`, `ModelsRepo`, `WindowsRepo`, `UsageRepo`) following the `ai.openai.storage` SQLite/rdb pattern (`db.sql`, `storage/models/`, numbered `storage/migrations/`, `PRAGMA user_version`).
  - `ai.router.AdminPages` — server-rendered etlua (`web.etlua`) HTML with a small self-contained stylesheet and no external assets; charts reuse the existing usage dashboard approach.
- Upstream adapters reuse existing clients instead of new protocol code and all return the same canonical shape (`ai.router.CanonicalMessage`): content, optional reasoning and tool calls, finish reason, and usage normalized to `{input_tokens, output_tokens, cached_input_tokens}`. Providers expose `complete(body, upstream_model)` and `completeStream(body, upstream_model, on_delta)`; local validation failures return a 400-shaped provider error so the server can fail without failover.
  - `OpenAIProvider` wraps `ai.openai.SubscriptionAuth` (one instance and auth file per subscription), `ai.openai.SubscriptionClient` (per request), and the Codex usage fetch (`fetchUsage`). Request validation and translation go through `ai.openai.ChatCompat`, the same module the standalone proxy uses; response assembly matches `ai.openai.ProxyServer` byte for byte.
  - `ZaiProvider` wraps `ai.zai.Client` with its GLM field allowlist and SSE semantics.
  - `CompatProvider` reuses `ai.zai.Client` as a generic Chat Completions transport for local llama.cpp: it forwards the client body verbatim with only the `model` field rewritten, streams deltas through unchanged, and reports upstream usage when the final chunk carries it. llama.cpp is a trusted local endpoint; no field allowlist is applied, and endpoints without a key receive a placeholder bearer that they ignore.
  - `ai.openai.SseParser` and `ai.openai.ProxyNetwork` are shared protocol-agnostic infrastructure and are reused directly.
- Routing is table-driven from database state, cached in memory and refreshed immediately after admin writes (single process, no cross-worker coordination):
  1. Authenticate the bearer key (SHA-256 hash lookup), reject disabled users, check the requested public model against the user's grants.
  2. Resolve the model chain: a custom model expands to its configured ordered target list; a concrete model is a chain of itself. Chain entries must be concrete catalog models; nesting custom models inside chains is rejected at save time, as are direct or indirect cycles.
  3. The public catalog is the union of custom models and every enabled subscription's model list; `/v1/models` returns its intersection with the user's grants.
  4. For each chain entry in order, candidates are the enabled subscriptions serving it, ordered by `priority` then `id`. Each candidate's upstream model is the subscription's permanent `model_redirects` mapping for that name, or the name itself.
  5. A subscription is **depleted** when a monitored window's fill is at or above that window's configured threshold and the data is fresh. Depleted subscriptions are skipped. If every candidate of every chain entry is depleted, the least-depleted candidate (lowest maximum window fill) is used instead of failing.
  6. A subscription in **cooldown** (recent upstream 401/403) is skipped like depleted ones but never used as a last resort while cooling down.
- Failover is bounded and honest:
  - Before any client-visible byte, upstream quota errors (429/`rate_limit_error`), authentication errors (401/403, plus cooldown), 5xx, and transport failures advance to the next candidate across the whole chain. A quota error also requests an immediate usage refresh for that subscription.
  - Provider-local request validation failures (unsupported parameter, malformed body) return `400` to the client without failover, because supported fields legitimately differ across providers.
  - Once the first upstream output byte has been relayed, no failover is possible; upstream failures surface as SSE `error` events or transport errors like the existing proxies.
  - To make pre-output failover possible, the router delays committing the downstream response — no status line, headers, or assistant-role chunk — until the first upstream output event arrives (or a non-streaming response completes). When all candidates fail before output, the client receives a real HTTP error status instead of a committed 200 with an SSE error.
- Usage window tracking:
  - `UsageMonitor` polls each subscription's usage source on a configurable interval (default 60 s) with jitter. `OpenAISubscriptionProvider` reads the Codex usage endpoint: `rate_limit.primary_window` is the 5-hour window and `secondary_window` the weekly one, each with `used_percent` and `reset_at`.
  - `ZaiProvider` reads the z.ai monitor endpoint `https://api.z.ai/api/monitor/usage/quota/limit` with the same Coding Plan API key as inference: `unit 3/number 5` is the 5-hour window and `unit 6/number 1` the rolling weekly window, each with `percentage` (integer used-percent), `usage`/`currentValue` (quota/consumption), and `nextResetTime` (epoch milliseconds).
  - Subscriptions without a usable upstream usage endpoint use **local counting**: `UsageRepo:subscriptionTokens` sums input plus output tokens from the router's own hourly usage aggregates over the trailing window, divided by a configured token quota, at hour-bucket granularity. This is an estimate; the spec does not claim provider-exact fill.
  - Each subscription declares `usage_source = "upstream" | "local"` per window (default by kind; `usage_url` overrides the zai monitor endpoint). The monitor wraps provider fetch calls in `pcall`: a raising or failing fetch keeps the previous snapshot — stale data never depletes. `UsageMonitor:refresh(subscription_id)` forces an immediate poll and is called after quota errors. Disabled subscriptions drop their in-memory window state. The last snapshot per window is persisted in `router_subscription_windows` so fills survive restarts and the admin can always show them; the monitor refreshes from upstream or recomputes from aggregates.
- Usage accounting follows the existing OpenAI proxy semantics, extended with a subscription dimension: requests are counted once at completion (including local rejections and upstream errors), input/output/cached tokens prefer provider-reported usage with the `ceil(JSON bytes / 4)` estimate as fallback, `estimated_requests` marks rows with missing provider counts, and no prompts, responses, keys, or addresses are persisted.
- Aggregates are hourly UTC upserts keyed by `(bucket, user, model, upstream_model, subscription)` where `model` is the public name the client requested and `upstream_model` is what was sent after the subscription's permanent redirect. `model_prices` in the config is keyed by upstream model, with the same cost formula and limitations as the OpenAI proxy.
- Admin authentication: a single operator password from the ignored config file. `POST /admin/login` issues a random 32-byte session id kept in memory with an expiry; the cookie is HttpOnly and SameSite=Strict. Forms carry a per-session CSRF token; mutations are POST-only and redirect back with inline validation errors. Restarting the server invalidates admin sessions, which is acceptable.
- Client API keys are generated by the server (32 random bytes, base64url), displayed exactly once at creation, and stored only as SHA-256 hashes plus a short non-secret hint for listing. Keys are never logged.

## Invariants

- Proxy model names for a user are exactly their grants; unknown or ungranted models fail with `404 model not found` before any upstream work.
- Custom model chains contain only concrete catalog models; direct or indirect cycles are rejected at save time.
- Every accepted request resolves to at most one serving subscription; failover iterates the candidate list at most once.
- Depletion decisions use only fresh window data (snapshot age below the configured `staleness` bound, default 120 s); stale data never marks a subscription depleted. The bound is flat across subscriptions: a subscription polling slower than `staleness` simply never depletes, which fails safe.
- All depleted never produces a failure while a non-cooldown candidate exists; cooldown candidates are never used as last resort.
- Downstream response commit happens only after the first upstream output event; nothing client-visible is sent for a request that later fails over.
- Provider-local validation failures never trigger failover and never silently drop unsupported fields.
- Requests require exactly one `Content-Length`; transfer encoding and duplicate lengths are rejected before buffering. Header, global connection, per-user concurrency, and per-user rate limits are enforced independently, with per-user configured overrides over the global defaults.
- Upstream request bodies sent to OpenAI subscriptions carry `store = false` and reject server-managed Responses state, matching the standalone proxy invariants. `[DONE]` terminates successful streams; a stream closed without `[DONE]` is an error unless canceled.
- Tool arguments are untrusted JSON strings; providers that relay them do so verbatim without parsing or rewriting.
- Streaming usage chunks honor `stream_options.include_usage` with the empty-`choices` final chunk shape, per provider capability.
- Proxy logs contain only the user name, remote address, method, path, status, duration, public model, and subscription used. Prompts, responses, client keys, admin password, session secrets, and upstream credentials are never logged or persisted.
- Upstream credential files (per-subscription OAuth stores, GLM API keys) live in ignored `userdata/` files or the database, never in the repository; the admin UI masks them.
- Every upstream request carries a unique `x-client-request-id`; bounded provider error details are returned with the matching request id.
- Statistics and steering counters are derived without storing message content; aggregates keep write volume to one upsert per completed request.

## Data Model (v1)

```sql
CREATE TABLE router_users (
	id INTEGER PRIMARY KEY,
	name TEXT NOT NULL UNIQUE,
	key_hash TEXT NOT NULL,
	key_hint TEXT NOT NULL,
	disabled INTEGER NOT NULL DEFAULT 0,
	max_concurrency INTEGER,
	max_rpm INTEGER,
	created_at INTEGER NOT NULL,
	updated_at INTEGER NOT NULL
);

CREATE TABLE router_user_models (
	user_id INTEGER NOT NULL,
	model TEXT NOT NULL,
	PRIMARY KEY (user_id, model)
);

CREATE TABLE router_subscriptions (
	id INTEGER PRIMARY KEY,
	name TEXT NOT NULL UNIQUE,
	kind TEXT NOT NULL,              -- openai | zai | openai_compat
	priority INTEGER NOT NULL,       -- lower value = preferred
	enabled INTEGER NOT NULL DEFAULT 1,
	config TEXT NOT NULL,            -- JSON, kind-specific
	limits TEXT NOT NULL,            -- JSON: thresholds, quotas, usage_source, poll interval
	created_at INTEGER NOT NULL,
	updated_at INTEGER NOT NULL
);

CREATE TABLE router_models (
	id INTEGER PRIMARY KEY,
	name TEXT NOT NULL UNIQUE,
	chain TEXT NOT NULL,             -- JSON ordered array of concrete model names
	description TEXT,
	created_at INTEGER NOT NULL,
	updated_at INTEGER NOT NULL
);

CREATE TABLE router_subscription_windows (
	subscription_id INTEGER NOT NULL,
	window TEXT NOT NULL,            -- five_hour | weekly
	used_percent REAL,
	used_tokens INTEGER,
	quota_tokens INTEGER,
	reset_at INTEGER,
	source TEXT NOT NULL,            -- upstream | local
	updated_at INTEGER NOT NULL,
	PRIMARY KEY (subscription_id, window)
);

CREATE TABLE router_usage_models (
	bucket INTEGER NOT NULL,
	user TEXT NOT NULL,
	model TEXT NOT NULL,             -- public model requested
	upstream_model TEXT NOT NULL,
	subscription TEXT NOT NULL,
	requests INTEGER NOT NULL,
	errors INTEGER NOT NULL,
	input_tokens INTEGER NOT NULL,
	output_tokens INTEGER NOT NULL,
	cached_input_tokens INTEGER NOT NULL DEFAULT 0,
	estimated_requests INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY (bucket, user, model, upstream_model, subscription)
);
```

- `router_subscriptions.config` JSON shape per kind:
  - `openai`: `{auth_path, models: string[], model_redirects: {[string]: string}, reasoning_effort?, verbosity?, max_response_size?}`
  - `zai`: `{base_url, api_key, models: string[], model_redirects: {[string]: string}, thinking?, tool_stream?, usage_url?}`
  - `openai_compat`: `{base_url, api_key?, models: string[], model_redirects: {[string]: string}}`
- `router_subscriptions.limits` JSON shape: `{five_hour_threshold?: number, weekly_threshold?: number, five_hour_quota_tokens?: number, weekly_quota_tokens?: number, usage_source?: {five_hour?: "upstream"|"local", weekly?: "upstream"|"local"}, poll_interval?: number}`
- Redirect sources must appear in that subscription's `models`; permanent redirects change only the upstream name. Aggregates and `model_prices` use the post-redirect upstream model.
- User, model, and subscription names in aggregates are snapshots; renaming starts a new series, as in the existing proxy.

## Client Endpoints

- `POST /v1/chat/completions` — Chat Completions JSON and SSE, translated per selected provider.
- `GET /v1/models` — the user's granted public models, `owned_by: "router"`.
- No `/v1/responses`, `/v1/embeddings`, or client-facing `/v1/usage` in v1; statistics live in the admin panel.

## Admin Endpoints

- `GET /admin` — login form; `POST /admin/login`, `POST /admin/logout`.
- Users: list, create (key shown once), edit grants and per-user limits, disable/enable, revoke and regenerate key.
- Subscriptions: list with live status, create, edit (kind-specific fields, priority, thresholds, credentials), enable/disable. OpenAI subscriptions link to the login command for their auth file.
- Models: list catalog, create/edit custom models with ordered chains, delete.
- Usage: totals, per-user, per-model, and per-subscription views over 24/168 hourly buckets with charts, cost estimates, errors, and estimated counts.
- Status: per-subscription window fills, freshness, reset countdowns, cooldown state, last poll time.

## Configuration

Copy `aqua/ai/router/proxy_config.example.lua` to the ignored `userdata/ai_router.lua`:

```lua
return {
	host = "127.0.0.1",
	port = 28083,
	admin_password = "replace-with-a-long-random-password",
	session_secret = "replace-with-32-plus-random-chars",
	db_path = "userdata/ai_router.db",
	network_path = "userdata/network.lua",
	tls_cafile = "resources/certs/cacert.pem",
	model_prices = {},             -- keyed by upstream model, USD per million tokens
	upstream_timeout = 300,
	client_timeout = 300,
	max_body_size = 16 * 1024 * 1024,
	max_response_size = 4 * 1024 * 1024,
	max_clients = 64,
	max_concurrent_requests_per_user = 4,
	max_requests_per_minute = 120,
	usage_poll_interval = 60,       -- seconds, per-subscription override in limits
	unhealthy_cooldown = 600,       -- seconds
	staleness = 120,               -- seconds; older window data never depletes
}
```

OpenAI subscription OAuth credentials are stored per subscription in ignored files such as `userdata/ai_router_auth_<name>.lua`. Device authorization login:

```bash
./luajit aqua/ai/router/proxy.lua login <subscription_name>
```

## Verification

- `ai.router.Router` is tested as pure logic: chain resolution, cycle rejection, candidate ordering, depletion/last-resort/cooldown selection, and stale-data handling with injected window state and clock.
- Adapters are tested with the existing fake HTTP stream and scheduler patterns: failover before first output, no failover after first output, validation-error pass-through, usage accounting, and SSE fidelity per provider.
- `UsageMonitor` is tested with fake upstream usage responses and aggregate-driven local counting, including staleness and persistence of snapshots.
- Repos and database migrations are tested like `ai.openai.storage` (`RouterDatabase_test.lua`).
- Admin pages are tested for session/CSRF enforcement, grant enforcement after edits, and that credentials and keys never appear in rendered HTML or logs.
- Run with `./test aqua/ai/router`.

## Future Work and Open Questions

- Optional `/v1/responses` passthrough for OpenAI subscriptions, and `/v1/embeddings`.
- Per-user token budgets or spend caps in addition to model grants.
- Alternative balancing modes (round-robin within a priority tier) beyond strict sequential consumption.
- Rate-limit response headers (`x-ratelimit-*`) derived from window state.
- Admin audit log of configuration changes.
- Short cooldowns for repeated upstream 5xx failures.
