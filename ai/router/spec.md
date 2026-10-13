# AI Router

## Goal

Provide a standalone multi-subscription OpenAI-compatible router: one server that authenticates named users, routes Chat Completions requests across several upstream subscriptions (ChatGPT/Codex OAuth, GLM Coding Plan, local llama.cpp), steers traffic away from subscriptions whose 5-hour or weekly limits are nearly exhausted, supports custom model aliases with ordered fallback chains, and reports usage statistics — without depending on application-specific code beyond the existing `aqua/ai` clients.

## User Experience

- Operators manage subscriptions, users, grants, and model aliases through the router MCP server and an agent running on their own PC. The password-protected web admin panel is a read-only dashboard; its only POST operations are session login/logout.
- To connect ChatGPT directly, call `router_save_subscription` with kind `openai`, name, priority, and `config.models`; an ignored credential path is generated if omitted. Call `router_start_openai_login`, then poll `router_openai_login_status` for the verification URL, one-time code, expiry, and result. The operator approves the code in OpenAI's browser page on their PC. The router polls in the background and saves credentials; no compatibility proxy or browser launch on the server is needed.
- Operators create users with `router_create_user`, receive a generated API key once in the MCP result, and grant each user access to specific public models. Regeneration revokes the old key immediately. Agents must treat key-bearing tool results as secrets.
- Operators define custom model names with ordered fallback chains, for example `lite → glm-5.3-flash → gpt-6-luna`: requests prefer the first chain entry whose subscriptions are available and fall through to later entries when earlier ones are depleted.
- Clients point any OpenAI Chat Completions consumer at `POST /v1/chat/completions` (streaming and non-streaming) with their router key and see only the models they were granted in `GET /v1/models`.
- Subscriptions are consumed in priority order: traffic goes to the highest-priority subscription that serves the model and is not past its thresholds. When it crosses a threshold, new requests move to the next subscription; when its window resets, it becomes primary again.
- Upstream quota, authentication, and transport failures before any output transparently move the request to the next candidate; the client sees one clean response.
- The admin panel shows usage statistics like the existing OpenAI proxy dashboard: total spend, per-user, per-model, and per-subscription totals with hourly charts, request counts, errors, and estimated counts.
- The admin panel shows live subscription state: current 5-hour and weekly window fill, data source and freshness, reset times, and cooldown status.

## Architecture Decisions

- The router is a standalone Lua server on `web.http.Server` with `web.luasocket.CosocketScheduler`, mirroring `aqua/ai/openai/proxy.lua` and `aqua/ai/zai/proxy.lua`. It binds loopback by default and is exposed publicly through Nginx, like the existing proxies. It supersedes them operationally when stable; they remain untouched.
- Package layout and responsibilities:
  - `proxy.lua` — standalone entrypoint, loads the ignored `userdata/ai_router.lua` config.
  - `ai.router.Server` — HTTP handling: client authentication, request limits, `/v1/*` endpoints, `/admin/*` endpoints, admin sessions.
  - `ai.router.Catalog` builds and deep-validates the routing state from repository rows (kind-specific config shapes, thresholds, redirect sources, concrete chain entries, alias nesting and shadowing). MCP saves validate through it before persisting; the runtime asserts a clean build. Default `usage_source` is `upstream` for openai and zai subscriptions and `local` for `openai_compat`.
  - `ai.router.Router` — model resolution and subscription selection (pure logic over in-memory state; injected clock and window data; unit-testable without sockets).
  - `ai.router.UsageMonitor` — polls upstream usage endpoints and maintains per-subscription window fill state; runs as a scheduler task.
  - `ai.router.Provider` declares the canonical provider contract (assistant message and usage shapes, streaming delta shapes) and shared normalization helpers; `OpenAIProvider`, `ZaiProvider`, and `CompatProvider` implement it.
  - `ai.router.storage.RouterDatabase` plus repos (`UsersRepo`, `SubscriptionsRepo`, `ModelsRepo`, `WindowsRepo`, `UsageRepo`) following the `ai.openai.storage` SQLite/rdb pattern (`db.sql`, `storage/models/`, numbered `storage/migrations/`, `PRAGMA user_version`).
  - `ai.router.AdminPages` — server-rendered etlua (`web.etlua`) HTML with a small self-contained stylesheet and no external assets; charts reuse the existing usage dashboard approach.
  - `ai.router.Management` — management domain operations, public/redacted views, full hypothetical-catalog validation, pending-login guards, synchronous SQLite transactions and selective catalog reloads with explicit persistence/application outcomes. No dependency on HTML or HTTP forms.
  - `ai.router.McpTools` — MCP-native tools with closed input schemas and read-only/destructive annotations; returns JSON text plus structured content. Domain validation errors are bounded, and unexpected errors never reflect SQL, credentials, OAuth responses, or stack traces.
  - `mcp.Server` — reused stateless Streamable HTTP transport on a separate privileged listener, sharing the router's scheduler and database, not the public inference listener. Its bearer token is always required, including on loopback. Browser Origin requests are rejected. Web cookies and client inference keys cannot authorize MCP.
  - `ai.router.OpenAILoginManager` — owns persistent per-auth-path OAuth instances and refresh guards, starts detached device-login coroutines through the same `SubscriptionAuth:loginWithDeviceCode` flow as `aqua/ai/openai`, and exposes bounded MCP login state; the dashboard reads only its status. Provider reconstruction reuses its guard, so catalog reloads cannot lose a pending login or authenticated credentials.
- `aqua/ai/router/proxy.lua` — standalone entrypoint: loads the ignored config, wires the database, network, monitor loop (5-second scheduler tick), read-only admin pages, MCP and inference listeners. `aqua/ai/router/smoke.lua` boots the full stack with a local mock upstream and exercises MCP → subscription/user → inference → usage, and rejects web mutations.
- Upstream adapters reuse existing clients instead of new protocol code and all return the same canonical shape (`ai.router.CanonicalMessage`): content, optional reasoning and tool calls, finish reason, and usage normalized to `{input_tokens, output_tokens, cached_input_tokens}`. Providers expose `complete(body, upstream_model)` and `completeStream(body, upstream_model, on_delta)`; local validation failures return a 400-shaped provider error so the server can fail without failover.
  - `OpenAIProvider` wraps `ai.openai.SubscriptionAuth` (one instance and auth file per subscription), `ai.openai.SubscriptionClient` (per request), and the Codex usage fetch (`fetchUsage`). Request validation and translation go through `ai.openai.ChatCompat`, the same module the standalone proxy uses; response assembly matches `ai.openai.ProxyServer` byte for byte.
  - `ZaiProvider` wraps `ai.zai.Client` with its GLM field allowlist and SSE semantics.
  - `CompatProvider` reuses `ai.zai.Client` as a generic Chat Completions transport for local llama.cpp: it forwards the client body verbatim with only the `model` field rewritten, streams deltas through unchanged, and reports upstream usage when the final chunk carries it. llama.cpp is a trusted local endpoint; no field allowlist is applied, and endpoints without a key receive a placeholder bearer that they ignore.
  - `ai.openai.SseParser` and `ai.openai.ProxyNetwork` are shared protocol-agnostic infrastructure and are reused directly.
- Routing is table-driven from database state, cached in memory and refreshed immediately after subscription/alias writes or explicit catalog reload (single process, no cross-worker coordination). User authentication, grants, and limits are read from repositories on each client request, so user/key writes take effect without reconstructing the catalog or providers:
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
- Dashboard authentication: a single operator password from the ignored config file. `POST /admin/login` issues an HMAC-signed stateless session cookie (`web.framework.Sessions`, HttpOnly, SameSite=Lax) carrying an expiry and a CSRF token; logout validates CSRF. All configuration-changing web routes are removed; authenticated non-GET requests outside login/logout return 405. Query parameters cannot reveal API keys or start operations. Dashboard cookies survive restart until expiry.
- Client API keys are generated by the server as random hex strings, returned once through MCP creation/regeneration, and stored only as SHA-256 hashes plus a short non-secret hint. The router never logs them; the local agent's handling and transcript retention are operator responsibilities.

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
- All management operations require the dedicated MCP bearer token. OpenAI creation generates a random `userdata/ai_router_auth_*.lua` path when omitted; saves require distinct auth paths across OpenAI subscriptions. Credentials are atomically replaced after token exchange and refresh. Missing credential files represent subscriptions awaiting login, not startup failures.
- Only one device login may run per auth path. Editing or deleting that subscription is blocked while login is pending (up to the shared 15-minute timeout). Other subscriptions and catalog mutations remain usable. Restarting the router abandons pending device flows but retains saved credentials. Successful login clears the subscription cooldown and requests usage refresh.
- Pending verification codes are returned only by authenticated MCP login tools, never by general listing/status tools or HTML. Private device IDs, token exchange data, stored credentials, key hashes, and raw OAuth exception/response text are never exposed. Error state allows a fresh login attempt.
- Management transactions never yield and are rolled back on validation/persistence failure. Catalog edits validate the complete hypothetical state before writes; deleting a subscription cannot break an alias. Only subscription/alias commits rebuild routing/providers; user/grant/key commits do not disturb provider instances or monitor wiring.
- Write results include `operation.persistence = "committed"|"not_committed"|"unknown"` and `operation.reload = "applied"|"failed"|"not_required"|"not_attempted"`, in both JSON text and structured content. `not_committed` means no write began or rollback succeeded; rollback failure reports `unknown`, requiring inspection/recovery rather than blind retries. Successful user/key writes report `committed`/`not_required`.
- A committed catalog write whose reload fails returns MCP `isError=true` **with its saved payload**, `committed`/`failed`, and a sanitized error. It is not a failed database write: never replay creation/deletion just because reload failed. `router_status.catalog_reload_pending` exposes the mismatch, and `router_reload_catalog` retries only runtime application without database mutations; its persistence value is `not_attempted`. User/key writes do not clear a pending reload.
- Catalog reload constructs all providers before publishing the new router/provider tables or replacing monitor wiring. A provider-construction failure leaves the previous live catalog and providers intact. Repository listings show saved data while `router_list_models.public_models` shows the live public catalog, which may differ until retry succeeds. Restart applies the saved catalog or fails startup; pending-reload state is process-local.
- MCP config patches preserve omitted credentials for same-kind edits; changing kind does not inherit the previous kind's config. Limits are complete replacements when supplied. Creation with `enabled=false` persists disabled, rather than silently enabling. General config reads omit API keys; URLs with userinfo, query strings or fragments are entirely redacted.
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

## Dashboard Endpoints

- `GET /admin` — login form; `POST /admin/login`, `POST /admin/logout`.
- `GET /admin/users` — users, key hints, grants, enabled state and per-user limits.
- `GET /admin/subscriptions` — subscriptions, served models, redirects, thresholds, window fills and OAuth status. No authorization code, credential or mutation controls.
- `GET /admin/models` — public catalog and custom model chains.
- Usage: totals, per-user, per-model, and per-subscription views over 24/168 hourly buckets with charts, cost estimates, errors, and estimated counts.
- Status: per-subscription window fills, freshness, reset countdowns, cooldown state, last poll time.

## MCP Management

- Streamable HTTP endpoint: `http://127.0.0.1:28084/mcp` by default, with `Authorization: Bearer <mcp_token>`. Configure the local agent's HTTP MCP connection with this URL and header. MCP initialize, tools/list, and tools/call use the shared `mcp.Server` protocol/version negotiation. No stdio or SSE transport is implemented.
- Read tools: `router_list_users`, `router_list_subscriptions`, `router_list_models`, `router_status`, `router_usage` (24 or 168 hours).
- Users: `router_create_user` (name, models), `router_update_user` (id plus optional name, disabled, models, max_concurrency, max_rpm), `router_regenerate_key`, `router_delete_user`.
- Subscriptions: `router_save_subscription` (omit id to create; supply id to patch), `router_delete_subscription`, `router_refresh_usage` (schedules polling).
- Recovery: `router_reload_catalog` reapplies the saved subscriptions/aliases after a reload failure, without replaying writes. Read `operation` and `isError` together; a committed result may still report failed runtime application.
- Aliases: `router_save_model` (omit id to create; supply id to patch name/chain/description), `router_delete_model`.
- Authorization: `router_start_openai_login`, `router_openai_login_status`. Pass subscription id. Start returns immediately; poll status for code availability and completion. Approval must be performed by the user, not autonomously by the agent.
- Tool discovery includes schemas, descriptions and safety annotations. Confirm destructive operations in the local agent. The MCP token grants full operator privileges, including upstream requests and credential path selection; do not give it to inference clients or untrusted agents.
- Keep the listener loopback-only unless intentionally publishing it through authenticated HTTPS or an SSH tunnel. Do not forward its token over plaintext networks; it is independent of `admin_password` and client keys.

## Configuration

Copy `aqua/ai/router/proxy_config.example.lua` to the ignored `userdata/ai_router.lua`:

```lua
return {
	host = "127.0.0.1",
	port = 28083,
	admin_password = "replace-with-a-long-random-password",
	mcp_token = "replace-with-a-separate-random-management-token",
	mcp_host = "127.0.0.1",
	mcp_port = 28084,
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

OpenAI subscription OAuth credentials are stored per subscription in ignored files such as `userdata/ai_router_auth_<random>.lua`. Device authorization is started through MCP. The operator must approve the returned code at `https://auth.openai.com/codex/device`; merely creating a subscription does not authenticate it. Existing `openai_compat` subscriptions remain unchanged and can coexist as fallback upstreams.

Configuration migration: every deployed router config (normally ignored `userdata/ai_router.lua`, or the path passed to `proxy.lua`) must add a separate random `mcp_token` of at least 32 characters before restarting; startup fails without it. Optional `mcp_host` and `mcp_port` default to loopback and 28084 and do not inherit the public inference bind address. Existing database rows and OAuth stores require no migration. Local development may load the token from a mode-0600 ignored `userdata/ai_router_mcp_token.lua`; never commit it. Publishing a remote MCP listener requires an explicit proxy/tunnel configuration change; it is not enabled by upgrading code.

## Verification

- `ai.router.Router` is tested as pure logic: chain resolution, cycle rejection, candidate ordering, depletion/last-resort/cooldown selection, and stale-data handling with injected window state and clock.
- Adapters are tested with the existing fake HTTP stream and scheduler patterns: failover before first output, no failover after first output, validation-error pass-through, usage accounting, and SSE fidelity per provider.
- `UsageMonitor` is tested with fake upstream usage responses and aggregate-driven local counting, including staleness and persistence of snapshots.
- Repos and database migrations are tested like `ai.openai.storage` (`RouterDatabase_test.lua`).
- Admin pages are tested for login/logout CSRF, a common read-only HTTP boundary, secret/code non-disclosure, and rendering of users, catalog, usage, and status. Removed web mutation routes are not maintained as individual scenarios; management and device-login behavior are covered by MCP tests.
- `McpTools_test` uses the native `mcp.Client` over real loopback sockets: initialization/discovery, dedicated-token and Origin enforcement, schema rejection, user key revocation without provider reload, transaction rollback, config patch credential preservation, disabled creation, catalog/alias validation, OAuth status/pending guards, usage and status, and committed reload failures with saved payloads and non-replaying recovery.
- Run with `./test aqua/ai/router`.
- Also run `./test aqua/mcp` and `./luajit aqua/ai/router/smoke.lua`.

## Future Work and Open Questions

- Optional `/v1/responses` passthrough for OpenAI subscriptions, and `/v1/embeddings`.
- Per-user token budgets or spend caps in addition to model grants.
- Alternative balancing modes (round-robin within a priority tier) beyond strict sequential consumption.
- Rate-limit response headers (`x-ratelimit-*`) derived from window state.
- Admin audit log of configuration changes.
- Short cooldowns for repeated upstream 5xx failures.
