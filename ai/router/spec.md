# AI Router

## Goal

Provide a standalone multi-subscription router: one server that authenticates named users, routes native Responses to ChatGPT/Codex OAuth subscriptions and Chat Completions to GLM Coding Plan or OpenAI-compatible upstreams, steers traffic away from subscriptions whose 5-hour or weekly limits are nearly exhausted, supports simple model aliases, and reports usage statistics — without translating between inference protocols or depending on application-specific code beyond the existing `aqua/ai` clients.

## User Experience

- Operators manage subscriptions, users, grants, and model aliases through the router MCP server and an agent running on their own PC. The password-protected web admin panel is a read-only dashboard; its only POST operations are session login/logout.
- To connect ChatGPT directly, call `router_save_subscription` with kind `openai`, name, priority, and `config.models`; an ignored credential path is generated if omitted. Call `router_start_openai_login`, then poll `router_openai_login_status` for the verification URL, one-time code, expiry, and result. The operator approves the code in OpenAI's browser page on their PC. The router polls in the background and saves credentials; no compatibility proxy or browser launch on the server is needed.
- Operators create users with `router_create_user`, receive a generated API key once in the MCP result, and grant each user access to specific public models. Regeneration revokes the old key immediately. Agents must treat key-bearing tool results as secrets.
- Operators define simple aliases, for example `lite → glm-5.3-flash`. Each alias has exactly one concrete model target. Requests may switch between subscriptions serving that target, but never fall back to a different model.
- Clients use `POST /v1/responses` for `openai` subscriptions and `POST /v1/chat/completions` for `zai`/`openai_compat`, with streaming and non-streaming support on each. Both endpoints use the same router key and grants; `GET /v1/models` lists the granted public catalog across protocols. A granted model served only through the other protocol returns `400 unsupported_protocol`, before provider work. Unknown/ungranted models still return `404 model_not_found`.
- Subscriptions are consumed in priority order: traffic goes to the highest-priority subscription that serves the model and is not past its thresholds. When it crosses a threshold, new requests move to the next subscription; when its window resets, it becomes primary again.
- Upstream quota, authentication, and transport failures before any output transparently move the request to the next candidate; the client sees one clean response.
- The admin panel shows usage statistics like the existing OpenAI proxy dashboard: total spend, per-user, per-model, and per-subscription totals with hourly charts, request counts, errors, and estimated counts.
- The admin panel shows live subscription state: current 5-hour and weekly window fill, data source and freshness, reset times, and cooldown status.

## Architecture Decisions

- The router is a standalone Lua server on `web.http.Server` with `web.luasocket.CosocketScheduler`, mirroring `aqua/ai/openai/proxy.lua` and `aqua/ai/zai/proxy.lua`. It binds loopback by default and is exposed publicly through Nginx, like the existing independently runnable proxies.
- Package layout and responsibilities:
  - `proxy.lua` — standalone entrypoint, loads the ignored `userdata/ai_router.lua` config.
  - `ai.router.Server` — HTTP handling: client authentication, request limits, `/v1/*` endpoints, `/admin/*` endpoints, admin sessions.
  - `ai.router.Catalog` builds and deep-validates the routing state from repository rows (kind-specific config shapes, thresholds, redirect sources, concrete alias targets, alias nesting and shadowing). MCP saves validate through it before persisting; the runtime asserts a clean build. Default `usage_source` is `upstream` for openai and zai subscriptions and `local` for `openai_compat`.
  - `ai.router.Router` — model resolution and subscription selection (pure logic over in-memory state; injected clock and window data; unit-testable without sockets).
  - `ai.router.UsageMonitor` — polls upstream usage endpoints and maintains per-subscription window fill state; runs as a scheduler task.
   - `ai.router.Provider` declares Chat Completions canonical message/delta shapes and shared usage normalization. Native Responses bypass the canonical assistant-message shape so provider-owned output items and typed events are not lost.
  - `ai.router.storage.RouterDatabase` plus repos (`UsersRepo`, `SubscriptionsRepo`, `ModelsRepo`, `WindowsRepo`, `UsageRepo`) following the SQLite/rdb pattern (`db.sql`, `storage/models/`, `PRAGMA user_version`). Schema version 2 uses a scalar alias target; no migration from schema version 1 is provided.
  - `ai.router.AdminPages` — server-rendered etlua (`web.etlua`) HTML with a small self-contained stylesheet and no external assets; charts reuse the existing usage dashboard approach.
  - `ai.router.Management` — management domain operations, public/redacted views, full hypothetical-catalog validation, pending-login guards, synchronous SQLite transactions and selective catalog reloads with explicit persistence/application outcomes. No dependency on HTML or HTTP forms.
  - `ai.router.McpTools` — MCP-native tools with closed input schemas and read-only/destructive annotations; returns JSON text plus structured content. Domain validation errors are bounded, and unexpected errors never reflect SQL, credentials, OAuth responses, or stack traces.
  - `mcp.Server` — reused stateless Streamable HTTP transport on a separate privileged listener, sharing the router's scheduler and database, not the public inference listener. Its bearer token is always required, including on loopback. Browser Origin requests are rejected. Web cookies and client inference keys cannot authorize MCP.
  - `ai.router.OpenAILoginManager` — owns persistent per-auth-path OAuth instances and refresh guards, starts detached device-login coroutines through the same `SubscriptionAuth:loginWithDeviceCode` flow as `aqua/ai/openai`, and exposes bounded MCP login state; the dashboard reads only its status. Provider reconstruction reuses its guard, so catalog reloads cannot lose a pending login or authenticated credentials.
- `aqua/ai/router/proxy.lua` — standalone entrypoint: loads the ignored config, wires the database, network, monitor loop (5-second scheduler tick), read-only admin pages, MCP and inference listeners. `aqua/ai/router/smoke.lua` boots the full stack with a local mock upstream and exercises MCP → subscription/user → inference → usage, and rejects web mutations.
- Upstream adapters reuse existing clients instead of new protocol code. Chat Completions providers return `ai.router.CanonicalMessage` (content, optional reasoning/tool calls, finish reason, and normalized usage) through `complete` / `completeStream`; local validation failures return a 400-shaped provider error without failover. Native OpenAI providers expose `createResponse(body, upstream_model, session_id, on_event?)` and return native response objects/events.
   - `OpenAIProvider` wraps `ai.openai.SubscriptionAuth` (one instance and auth file per subscription), `ai.openai.SubscriptionClient` (per request), and the Codex usage fetch (`fetchUsage`). It no longer imports `ChatCompat` or supports Chat Completions. `ai.openai.ResponsesProtocol` supplies the same stateless request and affinity validation used by the standalone OpenAI proxy. Existing Codex transport constraints/defaults still apply; this is not the complete public Responses API.
  - `ZaiProvider` wraps `ai.zai.Client` with its GLM field allowlist and SSE semantics.
  - `CompatProvider` reuses `ai.zai.Client` as a generic Chat Completions transport for local llama.cpp: it forwards the client body verbatim with only the `model` field rewritten, streams deltas through unchanged, and reports upstream usage when the final chunk carries it. llama.cpp is a trusted local endpoint; no field allowlist is applied, and endpoints without a key receive a placeholder bearer that they ignore.
  - `ai.openai.SseParser` and `ai.openai.ProxyNetwork` are shared protocol-agnostic infrastructure and are reused directly.
- Routing is table-driven from database state, cached in memory and refreshed immediately after subscription/alias writes or explicit catalog reload (single process, no cross-worker coordination). User authentication, grants, and limits are read from repositories on each client request, so user/key writes take effect without reconstructing the catalog or providers:
  1. Authenticate the bearer key (SHA-256 hash lookup), reject disabled users, check the requested public model against the user's grants.
   2. Resolve a simple alias to its single concrete target; a concrete model resolves to itself. Targets must be served by a configured subscription. Nested aliases, self-references, and shadowing of concrete model names are rejected.
  3. The public catalog is the union of custom models and every enabled subscription's model list; `/v1/models` returns its intersection with the user's grants.
   4. Candidates are the enabled subscriptions serving the resolved target, filtered by endpoint protocol before priority/quota/cooldown selection. Responses considers only `openai`; Chat Completions considers only `zai`/`openai_compat`. Each candidate's upstream model is its permanent redirect or the resolved name. Responses JSON and nested SSE response objects echo the requested public alias without changing response/item/call IDs or other provider-owned fields.
   5. A subscription is **depleted** when a monitored window's fill is at or above that window's configured threshold and the data is fresh. Depleted subscriptions are skipped. If every candidate for the target is depleted, the least-depleted candidate (lowest maximum window fill) is used instead of failing.
  6. A subscription in **cooldown** (recent upstream 401/403) is skipped like depleted ones but never used as a last resort while cooling down.
- Failover is bounded and honest:
   - Before any client-visible byte, upstream quota errors (429/`rate_limit_error`), authentication errors (401/403, plus cooldown), 5xx, and transport failures advance to the next subscription serving the same resolved model. A quota error also requests an immediate usage refresh for that subscription.
  - Provider-local request validation failures (unsupported parameter, malformed body) return `400` to the client without failover, because supported fields legitimately differ across providers.
   - Once downstream headers have been attempted, no failover is possible; upstream failures surface as SSE `error` events or transport errors like the existing proxies. A failed downstream write cancels the current upstream instead of starting another candidate.
   - Chat Completions delays commit until a non-empty, non-role delta (or a completion succeeds without deltas). Empty deltas and role-only announcements do not commit. Native Responses commits on the first typed event, including `response.created`, preserving event order and response identity; it does not buffer/discard those events to enable later failover. Before that first event, transport/auth/quota failures can switch only to another OpenAI subscription for the same model. After commit, failures use native `error` events/stream closure, never Chat Completions chunks or `[DONE]`.
- Usage window tracking:
  - `UsageMonitor` polls each subscription's usage source on a configurable interval (default 60 s) with jitter. `OpenAISubscriptionProvider` reads the Codex usage endpoint: `rate_limit.primary_window` is the 5-hour window and `secondary_window` the weekly one, each with `used_percent` and `reset_at`.
   - `ZaiProvider` reads the z.ai monitor endpoint `https://api.z.ai/api/monitor/usage/quota/limit` with the same Coding Plan API key as inference: `unit 3/number 5` is the 5-hour window and `unit 6/number 1` the rolling weekly window, each with `percentage` (integer used-percent), `usage`/`currentValue` (quota/consumption), and `nextResetTime` (epoch milliseconds). Its constructor wires the usage request function, key, and endpoint (including the optional `config.usage_url` override); provider tests exercise polling through a constructed instance.
  - Subscriptions without a usable upstream usage endpoint use **local counting**: `UsageRepo:subscriptionTokens` sums input plus output tokens from the router's own hourly usage aggregates over the trailing window, divided by a configured token quota, at hour-bucket granularity. This is an estimate; the spec does not claim provider-exact fill.
   - Each subscription declares `usage_source = "upstream" | "local"` per window (default by kind; `usage_url` overrides the zai monitor endpoint). The monitor wraps provider fetch calls in `pcall`: a raising or failing fetch keeps the previous in-memory snapshot — stale data never depletes. `UsageMonitor:refresh(subscription_id)` forces an immediate poll and is called after quota errors. Disabled subscriptions drop their in-memory window state. Quotas are neither read from nor written to the database. After restart they are unknown until a successful poll or local recomputation; catalog reloads preserve the current process's snapshots. Request/token statistics remain persistent. The legacy `router_subscription_windows` table and repo are retained for schema compatibility, but unused by runtime monitoring; existing rows are left untouched.
- Usage accounting follows the existing OpenAI proxy semantics, extended with a subscription dimension: requests are counted once at completion (including local rejections and upstream errors), input/output/cached tokens prefer provider-reported usage with the `ceil(JSON bytes / 4)` estimate as fallback, `estimated_requests` marks rows with missing provider counts, and no prompts, responses, keys, or addresses are persisted.
- Aggregates are hourly UTC upserts keyed by `(bucket, user, model, upstream_model, subscription)` where `model` is the public name the client requested and `upstream_model` is what was sent after the subscription's permanent redirect. `model_prices` in the config is keyed by upstream model, with the same cost formula and limitations as the OpenAI proxy.
- Dashboard authentication: a single operator password from the ignored config file. `POST /admin/login` issues an HMAC-signed stateless session cookie (`web.framework.Sessions`, HttpOnly, SameSite=Lax) carrying an expiry and a CSRF token; logout validates CSRF. All configuration-changing web routes are removed; authenticated non-GET requests outside login/logout return 405. Query parameters cannot reveal API keys or start operations. Dashboard cookies survive restart until expiry.
- Client API keys are generated by the server as random hex strings, returned once through MCP creation/regeneration, and stored only as SHA-256 hashes plus a short non-secret hint. The router never logs them; the local agent's handling and transcript retention are operator responsibilities.

## Invariants

- Every router MCP tool advertises an object `outputSchema` with strict success/error alternatives (`anyOf`), nested field types, required payloads, and no extra fields. Both alternatives are validated, including execution errors. Public configs exclude credentials; only user creation/key regeneration can return an API key, and only device-login tools can return verification codes. Empty config dictionaries, limits, redirects, and usage sources serialize as objects, not arrays; no database migration is needed.
- The router tool adapter validates results before the generic MCP server. Invalid payloads are replaced with sanitized structured errors while retaining valid persistence/reload metadata; malformed metadata or unexpected exceptions report unknown persistence for mutations. Output validation never rolls back a completed write or instructs callers to replay it. A malformed key-creation response may require inspecting the user and explicitly regenerating its key, not creating it again.

- Proxy model names for a user are exactly their grants; unknown or ungranted models fail with `404 model not found` before any upstream work.
- Each alias has one scalar `target` naming a concrete catalog model; arrays and the old `chain` API field are not supported. Nested aliases and self-references are rejected at save time. Grants apply to the requested public name, so access to an alias does not require a separate grant to its target.
- Every accepted request resolves to at most one serving subscription; failover iterates the candidate list at most once.
- Depletion decisions use only fresh window data (snapshot age below the configured `staleness` bound, default 120 s); stale data never marks a subscription depleted. The bound is flat across subscriptions: a subscription polling slower than `staleness` simply never depletes, which fails safe.
- All depleted never produces a failure while a non-cooldown candidate exists; cooldown candidates are never used as last resort.
- Downstream response commit happens only after the first upstream output event; nothing client-visible is sent for a request that later fails over.
- Provider-local validation failures never trigger failover and never silently drop unsupported fields.
- Requests require exactly one `Content-Length`; transfer encoding and duplicate lengths are rejected before buffering. Header, global connection, per-user concurrency, and per-user rate limits are enforced independently, with per-user configured overrides over the global defaults.
- Request-rate and concurrency counters are keyed by user id, not bearer token: key rotation cannot evade limits or lose the bookkeeping for in-flight requests. Every acquired slot is released even if body reading, routing, provider code, or downstream writing raises. Provider exceptions become sanitized upstream failures; unexpected handler failures become sanitized internal errors, never raw exception text.
- Streaming results retain the selected subscription/upstream model for accounting. Accounting and logs use the logical outcome: `400` for provider-local rejection, `502` for an upstream failure after SSE commit, and `499` for a failed downstream write, even when the already-sent HTTP status remains `200`. A terminal/usage/`[DONE]` write failure is not recorded as success. Failed intermediate fallback attempts are not separate usage rows.
- Z.ai and compatible streaming timeouts are total request deadlines covering connection, upload, headers, and stream reads, not reset idle timeouts per chunk. Continuous chunks cannot extend a stream indefinitely. Shared streaming clients close their active stream and clear its reference on exceptions, and ignore coalesced SSE events after cancellation, parse errors, or terminal completion. Non-JSON upstream HTTP errors retain their status so authentication cooldowns and quota refreshes still work.
- Client disconnection is observed through failed downstream writes. A client that disconnects while upstream is silent may remain active until the next output or the configured upstream deadline; there is no independent downstream-disconnect watcher.
- OpenAI requests carry `store=false` and reject stored/conversation state and background mode, matching the standalone Responses-only proxy. Native streaming preserves typed events and never emits `[DONE]`; Chat Completions retains its existing chunk/`[DONE]` contract. Native `failed` responses remain provider response objects (HTTP 200 with failed status) but count as logical failures in statistics; incomplete responses remain successful partial results. Valid terminal response objects are not retried, and quota failures request a usage refresh.
- Native Responses usage is normalized only for statistics, not for client output. Missing usage estimates input from `input`/`instructions`/tools and output from native output items. Reasoning content, prompts and tool data are never persisted. Failed downstream writes count as 499; neither endpoint retries after a commit attempt. User limits and slot release apply equally to both endpoints.
- Native cache affinity preserves validated `x-session-affinity`, `session_id`, or `x-client-request-id` in that priority order, or derives a SHA-256 identifier from `prompt_cache_key`. The same identifier survives pre-event failover; each upstream request still receives a fresh request ID. Affinity is a routing hint, not a guarantee of a cache hit across subscriptions.
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
	target TEXT NOT NULL,            -- single concrete model name
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

- `POST /v1/responses` — native stateless Responses JSON and typed SSE, OpenAI subscriptions only.
- `POST /v1/chat/completions` — Chat Completions JSON and SSE, GLM and compatible subscriptions only.
- `GET /v1/models` — the user's granted public models, `owned_by: "router"`.
- No `/v1/embeddings` or client-facing `/v1/usage`; statistics live in the admin panel and MCP.

## Dashboard Endpoints

- `GET /admin` — login form; `POST /admin/login`, `POST /admin/logout`.
- `GET /admin/users` — users, key hints, grants, enabled state and per-user limits.
- `GET /admin/subscriptions` — subscriptions, served models, redirects, thresholds, window fills and OAuth status. No authorization code, credential or mutation controls.
- `GET /admin/models` — public catalog and simple aliases with their targets.
- Usage: totals, per-user, per-model, and per-subscription views over 24/168 hourly buckets with charts, cost estimates, errors, and estimated counts.
- Status: per-subscription window fills, freshness, reset countdowns, cooldown state, last poll time.

## MCP Management

- Streamable HTTP endpoint: `http://127.0.0.1:28084/mcp` by default, with `Authorization: Bearer <mcp_token>`. Configure the local agent's HTTP MCP connection with this URL and header. MCP initialize, tools/list, and tools/call use the shared `mcp.Server` protocol/version negotiation. No stdio or SSE transport is implemented.
- Read tools: `router_list_users`, `router_list_subscriptions`, `router_list_models`, `router_status`, `router_usage` (24 or 168 hours).
- Users: `router_create_user` (name, models), `router_update_user` (id plus optional name, disabled, models, max_concurrency, max_rpm), `router_regenerate_key`, `router_delete_user`.
- Subscriptions: `router_save_subscription` (omit id to create; supply id to patch), `router_delete_subscription`, `router_refresh_usage` (schedules polling).
- Recovery: `router_reload_catalog` reapplies the saved subscriptions/aliases after a reload failure, without replaying writes. Read `operation` and `isError` together; a committed result may still report failed runtime application.
- Aliases: `router_save_model` (omit id to create; supply id to patch name/target/description), `router_delete_model`. `target` is a string, not a list; list/save results expose `target` instead of `chain`.
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

Configuration migration: every deployed router config (normally ignored `userdata/ai_router.lua`, or the path passed to `proxy.lua`) must add a separate random `mcp_token` of at least 32 characters before restarting; startup fails without it. Optional `mcp_host` and `mcp_port` default to loopback and 28084 and do not inherit the public inference bind address. OAuth stores remain usable. Local development may load the token from a mode-0600 ignored `userdata/ai_router_mcp_token.lua`; never commit it. Publishing a remote MCP listener requires an explicit proxy/tunnel configuration change; it is not enabled by upgrading code.

### Database Compatibility

- Simple aliases use schema version 2 (`router_models.target TEXT`), replacing the old JSON `chain` column. Per the chosen feature redesign, there is **no migration** or compatibility layer. Startup rejects a version-1 database without modifying its data.
- Before deploying this version with an old database, preserve the old database and update `db_path` in the environment's router config (normally `userdata/ai_router.lua`) to a new database file. It starts empty: users, grants, subscriptions, aliases, and usage history are not automatically transferred. Do not delete or overwrite an existing database as part of an ordinary code update. Reusing OAuth files requires explicitly configuring the corresponding subscriptions again.
- Management clients must send a scalar `target` to `router_save_model` and read `target` from alias results instead of `chain`; no new inference protocol or alias grant is needed.

## Verification

- Native Responses tests cover endpoint isolation, auth/grants, local state/affinity validation, alias/redirect handling, preservation of reasoning/tool items, cache usage accounting, pre-event failover and quota refresh, no failover after `response.created`, cooldown/depletion steering, and downstream write failures. Existing Chat Completions failover tests use a Chat Completions-compatible fallback rather than translating through an OpenAI subscription.
- Client migration is required: existing OpenAI router clients must switch from `/v1/chat/completions` to `/v1/responses` and native request/stream shapes. GLM/compat clients remain unchanged. No database or production config field migration is needed; production clients must be updated before deploying this breaking protocol split. Full stored/background/WebSocket Responses support remains out of scope, as documented in `../openai/spec.md`.

- Monitor tests verify that quota snapshots live only in memory, survive catalog reloads but not process restarts, and never read or overwrite legacy database snapshots. Failed polls preserve the current process's last-known values and original timestamps.
- The entrypoint starts polling via `UsageMonitor:startPolling`: detaching a coroutine alone does not execute it. The loop is explicitly resumed and checks due subscriptions every five seconds. Scheduler-driven tests verify the initial poll and subsequent polls after an upstream failure.

- `ai.router.Router` is tested as pure logic: single-target alias resolution, invalid/nested target rejection, same-model candidate ordering, depletion/last-resort/cooldown selection, and stale-data handling with injected window state and clock. Server tests verify that aliases never switch to unrelated models.
- Adapters are tested with the existing fake HTTP stream and scheduler patterns: failover before first output, no failover after first output, validation-error pass-through, usage accounting, and SSE fidelity per provider.
- `UsageMonitor` is tested with fake upstream usage responses and aggregate-driven local counting, including staleness and in-memory snapshot lifetime.
- Repos and database initialization are tested like `ai.openai.storage` (`RouterDatabase_test.lua`), including rejection of the old schema without modifying its rows or columns.
- Admin pages are tested for login/logout CSRF, a common read-only HTTP boundary, secret/code non-disclosure, and rendering of users, catalog, usage, and status. Removed web mutation routes are not maintained as individual scenarios; management and device-login behavior are covered by MCP tests.
- `McpTools_test` uses the native `mcp.Client` over real loopback sockets: initialization/discovery, dedicated-token and Origin enforcement, schema rejection, user key revocation without provider reload, transaction rollback, config patch credential preservation, disabled creation, catalog/alias validation, OAuth status/pending guards, usage and status, and committed reload failures with saved payloads and non-replaying recovery.
- Run with `./test aqua/ai/router`.
- `Server_test` covers bounded pre-output fallback for 429/5xx/transport failures, role-only chunks, no fallback after output, auth cooldown expiry, sanitized exceptions and slot cleanup, user-limit overrides/key rotation, terminal-write failure accounting, and real loopback upstream timeouts and downstream disconnect cancellation. Shared client tests cover coalesced SSE terminal/cancellation boundaries and exception cleanup.
- Also run `./test aqua/mcp` and `./luajit aqua/ai/router/smoke.lua`.

## Future Work and Open Questions

- Optional `/v1/responses` passthrough for OpenAI subscriptions, and `/v1/embeddings`.
- Per-user token budgets or spend caps in addition to model grants.
- Alternative balancing modes (round-robin within a priority tier) beyond strict sequential consumption.
- Rate-limit response headers (`x-ratelimit-*`) derived from window state.
- Admin audit log of configuration changes.
- Short cooldowns for repeated upstream 5xx failures.
