# AI Router

## Goal

Provide a standalone multi-channel router: one server that authenticates named users, routes native Responses to ChatGPT/Codex OAuth channels and Chat Completions to GLM Coding Plan or OpenAI-compatible upstreams, supports explicit channel selection and simple model aliases, and reports usage statistics — without automatic failover or protocol translation.

## User Experience

- Operators manage channels, users, grants, and model aliases through the router MCP server and an agent running on their own PC. The password-protected web admin panel is a read-only dashboard; its only POST operations are session login/logout.
- A channel is an inference destination: either a subscription account (`openai` or `zai`) or a compatible proxy (`openai_compat`, currently Chat Completions only). Channels need not represent subscriptions.
- To connect ChatGPT directly, call `router_save_channel` with kind `openai`, name and `config.models`; an ignored credential path is generated if omitted. Call `router_start_openai_login`, then poll `router_openai_login_status` for the verification URL, one-time code, expiry, and result. The operator approves the code in OpenAI's browser page on their PC. The router polls in the background and saves credentials; no compatibility proxy or browser launch on the server is needed.
- Operators create users with `router_create_user`, receive a generated API key once in the MCP result, and grant each user access to specific public models. Regeneration revokes the old key immediately. Agents must treat key-bearing tool results as secrets.
- Public concrete model names are `channel/model`, for example `openai-plus/gpt-6-astra` and `openai-pro/gpt-6-astra`. Prefixes are channel names, not provider kinds. Channel names contain 1–64 ASCII letters, digits or `._-`; upstream model names may contain slashes, preserved after the first separator. Renaming a channel changes its public model names and requires updating grants and aliases explicitly.
- Optional aliases, for example `fast → openai-pro/gpt-6-astra`, pin both channel and model. Bare upstream model names are not resolved implicitly.
- Clients use `POST /v1/responses` for `openai` channels and `POST /v1/chat/completions` for `zai`/`openai_compat`, with streaming and non-streaming support on each. Both endpoints use the same router key and grants; `GET /v1/models` lists the granted public catalog across protocols. A granted model served only through the other protocol returns `400 unsupported_protocol`, before provider work. Unknown/ungranted models still return `404 model_not_found`.
- Every inference request makes at most one provider call to its selected channel. Quota/auth/5xx errors retain their upstream HTTP status before streaming begins; transport failures return 502. No retry, failover, cooldown, priority or quota-based steering exists. Disabled direct models are absent from the catalog; an alias to a disabled channel returns 503.
- The admin panel shows usage statistics like the existing OpenAI proxy dashboard: total spend, per-user, per-model, and per-channel totals with hourly charts, request counts, errors, and estimated counts.
- The admin panel shows informational 5-hour and weekly window fill, data source, freshness and reset times. Quotas never affect routing.
- A single Channels page combines configuration and live status: bare model names with inline redirects, separate 5h/weekly quotas, token counts, update age, reset time and OpenAI login status. Channel prefixes are omitted only in this per-channel table; client model IDs and the Models page remain qualified. Upstream quotas have no `(upstream)` suffix; local quota estimates are labelled explicitly.
- The kind cell shows OpenAI login status or Z.ai API-key presence as muted secondary text, matching quota details. No separate login column or key value is displayed.
- The read-only Requests page lists completed authenticated inference attempts: ID, start time, user, requested model, selected channel, upstream model, protocol, streaming, logical status, total duration, input/cache/output tokens. Exact-match user/model/channel and success/error filters combine with stable 50-row cursor pagination. Estimated counts have a `~` prefix. No prompts, responses, credentials or error text are stored.
- Requests also shows streaming TTFT, output tokens/s and a short sanitized error category beneath the status. Unknown metrics appear as `—`, not zero. Ordinary JSON responses do not expose first-token timing or generation speed.
- Requests combines protocol and transport (`Responses · SSE`, `Chat Completions · JSON`). The upstream model appears as muted secondary text below the requested model only for aliases/redirects or another actual name difference; a matching `channel/model` prefix alone does not count as a difference.
- Operators can explicitly call `router_test_channel` with channel ID and a configured unqualified model to check authentication and native inference with one short request. This is not a free health check: it consumes provider quota. No prompt or generated output is returned or persisted; the diagnostic reports success, protocol, resolved model, elapsed time, logical status, sanitized error category and reported token counts.

## Architecture Decisions

- The router is a standalone Lua server on `web.http.Server` with `web.luasocket.CosocketScheduler`, mirroring `aqua/ai/openai/proxy.lua` and `aqua/ai/zai/proxy.lua`. It binds loopback by default and is exposed publicly through Nginx, like the existing independently runnable proxies.
- Package layout and responsibilities:
  - `proxy.lua` — standalone entrypoint, loads the ignored `userdata/ai_router.lua` config.
  - `ai.router.Server` — HTTP handling: client authentication, request limits, `/v1/*` endpoints, `/admin/*` endpoints, admin sessions.
  - `ai.router.Catalog` builds and deep-validates qualified model names, kind-specific configs, monitoring limits, redirects and aliases. MCP saves validate through it before persisting; runtime asserts a clean build. Default `usage_source` is `upstream` for openai/zai and `local` for `openai_compat`.
  - `ai.router.Router` — pure resolution of a qualified name or alias to exactly one enabled channel and its unqualified upstream model. No clock or quota state is needed.
  - `ai.router.UsageMonitor` — polls upstream usage endpoints and maintains per-channel window fill state; runs as a scheduler task.
   - `ai.router.Provider` declares Chat Completions canonical message/delta shapes and shared usage normalization. Native Responses bypass the canonical assistant-message shape so provider-owned output items and typed events are not lost.
   - `ai.router.storage.RouterDatabase` plus repos follow the SQLite/rdb pattern. Schema version 6 extends bounded request metadata with nullable timing/error fields; earlier databases are rejected without modification. No runtime migration is provided.
   - `ai.router.RequestLogsRepo` persists individual completion records independently of hourly usage, retaining at most 10,000 entries for seven days. Inserts prune expired/excess rows; reads hide expired rows even when idle. Log write failures are sanitized and never change the inference outcome.
  - `ai.router.AdminPages` — server-rendered etlua (`web.etlua`) HTML with a small self-contained stylesheet and no external assets; charts reuse the existing usage dashboard approach.
  - `ai.router.Management` — management domain operations, public/redacted views, full hypothetical-catalog validation, pending-login guards, synchronous SQLite transactions and selective catalog reloads with explicit persistence/application outcomes. No dependency on HTML or HTTP forms.
  - `ai.router.McpTools` — MCP-native tools with closed input schemas and read-only/destructive annotations; returns JSON text plus structured content. Domain validation errors are bounded, and unexpected errors never reflect SQL, credentials, OAuth responses, or stack traces.
  - `mcp.Server` — reused stateless Streamable HTTP transport on a separate privileged listener, sharing the router's scheduler and database, not the public inference listener. Its bearer token is always required, including on loopback. Browser Origin requests are rejected. Web cookies and client inference keys cannot authorize MCP.
  - `ai.router.OpenAILoginManager` — owns persistent per-auth-path OAuth instances and refresh guards, starts detached device-login coroutines through the same `SubscriptionAuth:loginWithDeviceCode` flow as `aqua/ai/openai`, and exposes bounded MCP login state; the dashboard reads only its status. Provider reconstruction reuses its guard, so catalog reloads cannot lose a pending login or authenticated credentials.
- `aqua/ai/router/proxy.lua` — standalone entrypoint: loads the ignored config, wires the database, network, monitor loop (5-second scheduler tick), read-only admin pages, MCP and inference listeners. `aqua/ai/router/smoke.lua` boots the full stack with a local mock upstream and exercises MCP → channel/user → inference → usage, and rejects web mutations.
- Upstream adapters reuse existing clients instead of new protocol code. Chat Completions providers return `ai.router.CanonicalMessage` (content, optional reasoning/tool calls, finish reason, and normalized usage) through `complete` / `completeStream`; local validation failures return a 400-shaped provider error without failover. Native OpenAI providers expose `createResponse(body, upstream_model, session_id, on_event?)` and return native response objects/events.
   - `OpenAIProvider` wraps `ai.openai.SubscriptionAuth` (one instance and auth file per channel), `ai.openai.SubscriptionClient` (per request), and the Codex usage fetch (`fetchUsage`). It no longer imports `ChatCompat` or supports Chat Completions. `ai.openai.ResponsesProtocol` supplies the same stateless request and affinity validation used by the standalone OpenAI proxy. Existing Codex transport constraints/defaults still apply; this is not the complete public Responses API.
  - `ZaiProvider` wraps `ai.zai.Client` with its GLM field allowlist and SSE semantics.
  - `CompatProvider` reuses `ai.zai.Client` as a generic Chat Completions transport for local llama.cpp: it forwards the client body verbatim with only the `model` field rewritten, streams deltas through unchanged, and reports upstream usage when the final chunk carries it. llama.cpp is a trusted local endpoint; no field allowlist is applied, and endpoints without a key receive a placeholder bearer that they ignore.
  - `ai.openai.SseParser` and `ai.openai.ProxyNetwork` are shared protocol-agnostic infrastructure and are reused directly.
- Routing is table-driven from database state, cached in memory and refreshed immediately after channel/alias writes or explicit catalog reload (single process, no cross-worker coordination). User authentication, grants, and limits are read from repositories on each client request, so user/key writes take effect without reconstructing the catalog or providers:
  1. Authenticate the bearer key (SHA-256 hash lookup), reject disabled users, check the requested public model against the user's grants.
   2. Resolve a simple alias to its single concrete target; a concrete model resolves to itself. Targets must be served by a configured channel. Nested aliases, self-references, and shadowing of concrete model names are rejected.
  3. The public catalog is the union of custom models and every enabled channel's model list; `/v1/models` returns its intersection with the user's grants.
   4. Split the resolved target at the first slash and select only that enabled channel. Check its endpoint protocol before provider work: Responses for `openai`, Chat Completions for `zai`/`openai_compat`. Remove the channel prefix and apply that channel's permanent redirect before sending upstream. Client responses echo the requested qualified name or alias without changing response/item/call IDs.
- Errors before response commit remain real HTTP errors; provider-local validation returns 400. After commit, failures use the endpoint's SSE error/closure contract. A failed downstream write cancels the upstream. Chat Completions commits on the first non-role output delta (or success); Responses commits on the first typed event, including `response.created`. No failure ever selects a different channel.
- Usage window tracking:
   - `UsageMonitor` polls each channel's usage source on a configurable interval (default 60 s) with jitter. `OpenAIProvider` reads the Codex usage endpoint: `rate_limit.primary_window` is the 5-hour window and `secondary_window` the weekly one, each with `used_percent` and `reset_at`.
   - `ZaiProvider` reads the z.ai monitor endpoint `https://api.z.ai/api/monitor/usage/quota/limit` with the same Coding Plan API key as inference: `unit 3/number 5` is the 5-hour window and `unit 6/number 1` the rolling weekly window, each with `percentage` (integer used-percent), `usage`/`currentValue` (quota/consumption), and `nextResetTime` (epoch milliseconds). Its constructor wires the usage request function, key, and endpoint (including the optional `config.usage_url` override); provider tests exercise polling through a constructed instance.
  - Channels without a usable upstream usage endpoint use **local counting**: `UsageRepo:channelTokens` sums input plus output tokens from the router's own hourly usage aggregates over the trailing window, divided by a configured token quota, at hour-bucket granularity. This is an estimate; the spec does not claim provider-exact fill.
   - Each channel declares `usage_source = "upstream" | "local"` per window. Failed polls keep the last in-memory snapshot and timestamp. `UsageMonitor:refresh(channel_id)` requests immediate polling after quota errors. Disabled channels drop in-memory state. Quotas are neither loaded from nor written to SQLite; after restart they are unknown until polling/recomputation. Catalog reloads preserve snapshots. Request/token statistics remain persistent; the legacy window table/repo remain unused by runtime monitoring.
- Usage accounting follows the existing OpenAI proxy semantics, extended with a channel dimension: requests are counted once at completion (including local rejections and upstream errors), input/output/cached tokens prefer provider-reported usage with the `ceil(JSON bytes / 4)` estimate as fallback, `estimated_requests` marks rows with missing provider counts, and no prompts, responses, keys, or addresses are persisted.
- Aggregates are hourly UTC upserts keyed by `(bucket, user, model, upstream_model, channel)` where `model` is the public name the client requested and `upstream_model` is what was sent after the channel's permanent redirect. `model_prices` in the config is keyed by upstream model, with the same cost formula and limitations as the OpenAI proxy.
- Dashboard authentication: a single operator password from the ignored config file. `POST /admin/login` issues an HMAC-signed stateless session cookie (`web.framework.Sessions`, HttpOnly, SameSite=Lax) carrying an expiry and a CSRF token; logout validates CSRF. All configuration-changing web routes are removed; authenticated non-GET requests outside login/logout return 405. Query parameters cannot reveal API keys or start operations. Dashboard cookies survive restart until expiry.
- Client API keys are generated by the server as random hex strings, returned once through MCP creation/regeneration, and stored only as SHA-256 hashes plus a short non-secret hint. The router never logs them; the local agent's handling and transcript retention are operator responsibilities.

## Invariants

- Every router MCP tool advertises an object `outputSchema` with strict success/error alternatives (`anyOf`), nested field types, required payloads, and no extra fields. Both alternatives are validated, including execution errors. Public configs exclude credentials; only user creation/key regeneration can return an API key, and only device-login tools can return verification codes. Empty config dictionaries, limits, redirects, and usage sources serialize as objects, not arrays; no database migration is needed.
- The router tool adapter validates results before the generic MCP server. Invalid payloads are replaced with sanitized structured errors while retaining valid persistence/reload metadata; malformed metadata or unexpected exceptions report unknown persistence for mutations. Output validation never rolls back a completed write or instructs callers to replay it. A malformed key-creation response may require inspecting the user and explicitly regenerating its key, not creating it again.

- Proxy model names for a user are exactly their grants; unknown or ungranted models fail with `404 model not found` before any upstream work.
- Each alias has one scalar `target` naming a concrete catalog model; arrays and the old `chain` API field are not supported. Nested aliases and self-references are rejected at save time. Grants apply to the requested public name, so access to an alias does not require a separate grant to its target.
- Every accepted request targets exactly one channel/model pair, including aliases. It makes at most one provider call. Monitoring data, failures and other channels' availability cannot alter that pair.
- Bare model names are rejected unless explicitly registered as aliases; alias names contain no slash and targets must be qualified concrete models. Grants apply to the exact requested name, not all channels serving its suffix.
- Provider-local validation failures never silently drop unsupported fields.
- Requests require exactly one `Content-Length`; transfer encoding and duplicate lengths are rejected before buffering. Header, global connection, per-user concurrency, and per-user rate limits are enforced independently, with per-user configured overrides over the global defaults.
- Request-rate and concurrency counters are keyed by user id, not bearer token: key rotation cannot evade limits or lose the bookkeeping for in-flight requests. Every acquired slot is released even if body reading, routing, provider code, or downstream writing raises. Provider exceptions become sanitized upstream failures; unexpected handler failures become sanitized internal errors, never raw exception text.
- Streaming results retain the selected channel/upstream model for accounting, including failures before output. Logical failures after commit count as 502, downstream failures as 499, even when HTTP 200 has already been sent. Terminal/usage/`[DONE]` write failures are not successes.
- Z.ai and compatible streaming timeouts are total request deadlines covering connection, upload, headers and reads. Clients close active streams on exceptions and ignore events after cancellation or termination. Non-JSON upstream HTTP errors retain their status; quota errors still request a monitor refresh.
- Client disconnection is observed through failed downstream writes. A client that disconnects while upstream is silent may remain active until the next output or the configured upstream deadline; there is no independent downstream-disconnect watcher.
- OpenAI requests carry `store=false` and reject stored/conversation state and background mode, matching the standalone Responses-only proxy. Native streaming preserves typed events and never emits `[DONE]`; Chat Completions retains its existing chunk/`[DONE]` contract. Native `failed` responses remain provider response objects (HTTP 200 with failed status) but count as logical failures in statistics; incomplete responses remain successful partial results. Valid terminal response objects are not retried, and quota failures request a usage refresh.
- Native Responses usage is normalized only for statistics, not for client output. Missing usage estimates input from `input`/`instructions`/tools and output from native output items. Reasoning content, prompts and tool data are never persisted. Failed downstream writes count as 499; neither endpoint retries after a commit attempt. User limits and slot release apply equally to both endpoints.
- Native cache affinity preserves validated `x-session-affinity`, `session_id`, or `x-client-request-id` in that order, or derives a SHA-256 identifier from `prompt_cache_key`. Each upstream request still receives a fresh request ID. Affinity is a backend cache hint, not a cache-hit guarantee.
- Tool arguments are untrusted JSON strings; providers that relay them do so verbatim without parsing or rewriting.
- Streaming usage chunks honor `stream_options.include_usage` with the empty-`choices` final chunk shape, per provider capability.
- Proxy logs contain only the user name, remote address, method, path, status, duration, public model, and channel used. Prompts, responses, client keys, admin password, session secrets, and upstream credentials are never logged or persisted.
- Upstream credential files (per-channel OAuth stores, GLM API keys) live in ignored `userdata/` files or the database, never in the repository; the admin UI masks them.
- All management operations require the dedicated MCP bearer token. OpenAI creation generates a random `userdata/ai_router_auth_*.lua` path when omitted; saves require distinct auth paths across OpenAI channels. Credentials are atomically replaced after token exchange and refresh. Missing credential files represent channels awaiting login, not startup failures.
- Only one device login may run per auth path. Editing/deleting that channel is blocked while login is pending. Restart abandons pending flows but retains saved credentials. Successful login requests usage refresh.
- Pending verification codes are returned only by authenticated MCP login tools, never by general listing/status tools or HTML. Private device IDs, token exchange data, stored credentials, key hashes, and raw OAuth exception/response text are never exposed. Error state allows a fresh login attempt.
- Management transactions never yield and are rolled back on validation/persistence failure. Catalog edits validate the complete hypothetical state before writes; deleting a channel cannot break an alias. Only channel/alias commits rebuild routing/providers; user/grant/key commits do not disturb provider instances or monitor wiring.
- Write results include `operation.persistence = "committed"|"not_committed"|"unknown"` and `operation.reload = "applied"|"failed"|"not_required"|"not_attempted"`, in both JSON text and structured content. `not_committed` means no write began or rollback succeeded; rollback failure reports `unknown`, requiring inspection/recovery rather than blind retries. Successful user/key writes report `committed`/`not_required`.
- A committed catalog write whose reload fails returns MCP `isError=true` **with its saved payload**, `committed`/`failed`, and a sanitized error. It is not a failed database write: never replay creation/deletion just because reload failed. `router_status.catalog_reload_pending` exposes the mismatch, and `router_reload_catalog` retries only runtime application without database mutations; its persistence value is `not_attempted`. User/key writes do not clear a pending reload.
- Catalog reload constructs all providers before publishing the new router/provider tables or replacing monitor wiring. A provider-construction failure leaves the previous live catalog and providers intact. Repository listings show saved data while `router_list_models.public_models` shows the live public catalog, which may differ until retry succeeds. Restart applies the saved catalog or fails startup; pending-reload state is process-local.
- MCP config patches preserve omitted credentials for same-kind edits; changing kind does not inherit the previous kind's config. Limits are complete replacements when supplied. Creation with `enabled=false` persists disabled, rather than silently enabling. General config reads omit API keys; URLs with userinfo, query strings or fragments are entirely redacted.
- Every upstream request carries a unique `x-client-request-id`; bounded provider error details are returned with the matching request id.
- Statistics and local quota estimates are derived without storing message content; aggregates use one upsert per completed request.
- Request-log IDs are monotonically increasing completion-order cursors, not upstream request IDs. Rows retain start time and user/model/channel snapshots across renames/deletes. Duration includes streaming. Cache tokens are part of input, not additional consumption. Logical stream failures may be 502 after HTTP 200; downstream failures are 499. Malformed-body and pre-body rate/concurrency rejections have unknown model/channel and estimated zero tokens; invalid/disabled credentials and non-inference routes are excluded. Request logs do not change aggregate accounting or local quota estimates.
- `RequestMetrics` is per-request state, never shared between concurrent attempts. TTFT runs from handler entry to the first nonempty streamed text, reasoning, refusal, tool name/arguments (Chat Completions), tool arguments (Responses), or audio data. Role-only deltas, tool IDs/indexes, empty deltas and Responses lifecycle events do not start it. Timing observes provider callbacks, not first headers or guaranteed client receipt. `generation_ms` runs from first output until the provider call returns, excluding final router-generated terminal writes. Output tokens/s is derived on read as reported output tokens / generation seconds only for successful streams with positive intervals and output counts; estimates, failures and old rows have no rate. The rate includes relay/backpressure and terminal delays and may include reasoning tokens; it is not pure decoder throughput.
- Channel probes require an enabled, live configured channel/model and no pending catalog reload or OAuth login. They never pick a default model or resolve an alias, and apply the selected channel's permanent redirect exactly once. Only one probe per channel runs at a time; exceptions release that guard. Calls use the existing provider and configured deadlines without retry/fallback or a database transaction across network I/O. The fixed prompt asks for exactly OK; success means native inference completed, not an exact-content assertion. Chat Completions sends `max_tokens=16` and Z.ai disables thinking for this request; OpenAI Responses has no hard output cap, reflecting backend constraints. Native failed responses are logical failures. `probe.ok=false` is a successful diagnostic tool result, while invalid selections are MCP execution errors. OAuth refresh may persist credentials normally. Probes do not use a user key/grants, fabricate a user, write request history/usage aggregates, or affect local token estimates; upstream quotas still include them.
- Persisted error codes are a closed vocabulary: `rate_limit`, `concurrency_limit`, `timeout`, `auth`, `client_disconnected`, `model_not_found`, `unsupported_protocol`, `invalid_request`, `upstream_unavailable`, `upstream_error`, `internal_error`. Raw provider codes/text never enter this field. Provider status/type/known codes and transport timeout signals determine the category; unrecognized failures are generic. Post-commit logical failures retain the underlying category, disconnects take precedence, and successful requests have no error code. Old rows remain unknown rather than inferred retroactively.

## Data Model (schema version 6)

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

CREATE TABLE router_channels (
	id INTEGER PRIMARY KEY,
	name TEXT NOT NULL UNIQUE,
	kind TEXT NOT NULL,              -- openai | zai | openai_compat
	enabled INTEGER NOT NULL DEFAULT 1,
	config TEXT NOT NULL,            -- JSON, kind-specific
	limits TEXT NOT NULL,            -- JSON: display quotas, usage_source, poll interval
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

CREATE TABLE router_channel_windows (
	channel_id INTEGER NOT NULL,
	window TEXT NOT NULL,            -- five_hour | weekly
	used_percent REAL,
	used_tokens INTEGER,
	quota_tokens INTEGER,
	reset_at INTEGER,
	source TEXT NOT NULL,            -- upstream | local
	updated_at INTEGER NOT NULL,
	PRIMARY KEY (channel_id, window)
);

CREATE TABLE router_usage_models (
	bucket INTEGER NOT NULL,
	user TEXT NOT NULL,
	model TEXT NOT NULL,             -- public model requested
	upstream_model TEXT NOT NULL,
	channel TEXT NOT NULL,
	requests INTEGER NOT NULL,
	errors INTEGER NOT NULL,
	input_tokens INTEGER NOT NULL,
	output_tokens INTEGER NOT NULL,
	cached_input_tokens INTEGER NOT NULL DEFAULT 0,
	estimated_requests INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY (bucket, user, model, upstream_model, channel)
);

CREATE TABLE router_request_logs (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	created_at INTEGER NOT NULL,
	user TEXT NOT NULL,
	model TEXT NOT NULL,
	channel TEXT NOT NULL,
	upstream_model TEXT NOT NULL,
	protocol TEXT NOT NULL,
	stream INTEGER NOT NULL,
	status INTEGER NOT NULL,
	duration_ms INTEGER NOT NULL,
	input_tokens INTEGER NOT NULL,
	output_tokens INTEGER NOT NULL,
	cached_input_tokens INTEGER NOT NULL,
	estimated INTEGER NOT NULL,
	ttft_ms INTEGER,
	generation_ms INTEGER,
	error_code TEXT
);
CREATE INDEX router_request_logs_created_at ON router_request_logs (created_at);
```

- `router_channels.config` JSON shape per kind:
  - `openai`: `{auth_path, models: string[], model_redirects: {[string]: string}, reasoning_effort?, verbosity?, max_response_size?}`
  - `zai`: `{base_url, api_key, models: string[], model_redirects: {[string]: string}, thinking?, tool_stream?, usage_url?}`
  - `openai_compat`: `{base_url, api_key?, models: string[], model_redirects: {[string]: string}}`
- `router_channels.limits` JSON shape: `{five_hour_quota_tokens?: number, weekly_quota_tokens?: number, usage_source?: {five_hour?: "upstream"|"local", weekly?: "upstream"|"local"}, poll_interval?: number}`
- Redirect sources must appear in that channel's `models`; permanent redirects change only the upstream name. Aggregates and `model_prices` use the post-redirect upstream model.
- User, model, and channel names in aggregates are snapshots; renaming starts a new series, as in the existing proxy.

## Client Endpoints

- `POST /v1/responses` — native stateless Responses JSON and typed SSE, OpenAI channels only.
- `POST /v1/chat/completions` — Chat Completions JSON and SSE, GLM and compatible channels only.
- `GET /v1/models` — the user's granted public models, `owned_by: "router"`.
- No `/v1/embeddings` or client-facing `/v1/usage`; statistics live in the admin panel and MCP.

## Dashboard Endpoints

- `GET /admin` — login form; `POST /admin/login`, `POST /admin/logout`.
- `GET /admin/users` — users, key hints, grants, enabled state and per-user limits.
- `GET /admin/channels` — channels, unqualified models/redirects, quotas, token counts, freshness, reset times and OAuth status. No authorization code, credential or mutation controls. Replaces both old configuration/status pages; authenticated GETs to `/admin/subscriptions` and `/admin/status` redirect here. There is no separate Status navigation entry or template.
- `GET /admin/models` — public catalog and simple aliases with their targets.
- Usage: totals, per-user, per-model, and per-channel views over 24/168 hourly buckets with charts, cost estimates, errors, and estimated counts.
- `GET /admin/requests` — bounded request history with optional `user`, `model`, `channel`, `outcome=success|error` and `before` ID cursor. No mutation controls; refresh to see newer completions. Times use the server timezone. Historical aggregates cannot reconstruct individual requests from before this feature.

## MCP Management

- Streamable HTTP endpoint: `http://127.0.0.1:28084/mcp` by default, with `Authorization: Bearer <mcp_token>`. Configure the local agent's HTTP MCP connection with this URL and header. MCP initialize, tools/list, and tools/call use the shared `mcp.Server` protocol/version negotiation. No stdio or SSE transport is implemented.
- Read tools: `router_list_users`, `router_list_channels`, `router_list_models`, `router_status`, `router_usage` (24 or 168 hours).
- Channel management replaces `router_list_subscriptions` / `router_save_subscription` / `router_delete_subscription` without aliases. List/status payloads expose `channels`, save results expose `channel`, and usage rows expose `channel` instead of `subscription`. `router_status` remains the MCP health/monitoring tool, independent of the merged dashboard page. Reconnect MCP clients to refresh tool schemas.
- Users: `router_create_user` (name, models), `router_update_user` (id plus optional name, disabled, models, max_concurrency, max_rpm), `router_regenerate_key`, `router_delete_user`.
- Channels: `router_save_channel` (omit id to create; supply id to patch), `router_delete_channel`, `router_refresh_usage` (schedules polling).
- Recovery: `router_reload_catalog` reapplies the saved channels/aliases after a reload failure, without replaying writes. Read `operation` and `isError` together; a committed result may still report failed runtime application.
- Diagnostics: `router_test_channel({id, model})`, where `model` is an unqualified entry from that channel's `config.models`, not a qualified public ID or alias. The tool is external/non-read-only, not destructive. Invoke explicitly, never as an automatic listing/status/polling step. MCP clients must refresh discovery to see the new tool; no additional configuration or database migration is needed for probes or the compact table.
- Aliases: `router_save_model` (omit id to create; supply id to patch name/target/description), `router_delete_model`. `target` is a string, not a list; list/save results expose `target` instead of `chain`.
- Authorization: `router_start_openai_login`, `router_openai_login_status`. Pass channel id. Start returns immediately; poll status for code availability and completion. Approval must be performed by the user, not autonomously by the agent.
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
	usage_poll_interval = 60,       -- seconds, per-channel override in limits
}
```

OpenAI channel OAuth credentials are stored per channel in ignored files such as `userdata/ai_router_auth_<random>.lua`. Device authorization is started through MCP. The operator must approve the returned code at `https://auth.openai.com/codex/device`; merely creating a channel does not authenticate it.

Configuration migration: every deployed router config (normally ignored `userdata/ai_router.lua`, or the path passed to `proxy.lua`) must add a separate random `mcp_token` of at least 32 characters before restarting; startup fails without it. Optional `mcp_host` and `mcp_port` default to loopback and 28084 and do not inherit the public inference bind address. OAuth stores remain usable. Local development may load the token from a mode-0600 ignored `userdata/ai_router_mcp_token.lua`; never commit it. Publishing a remote MCP listener requires an explicit proxy/tunnel configuration change; it is not enabled by upgrading code.

### Database Compatibility

- Runtime initialization accepts only fresh or version-6 databases and never migrates existing data. Alias targets, grants, credentials and aggregate history remain unchanged.
- Before upgrading schema 5, stop the router and make a consistent SQLite backup (including WAL). In a manual transaction, run `ALTER TABLE router_request_logs ADD COLUMN ttft_ms INTEGER`, `ALTER TABLE router_request_logs ADD COLUMN generation_ms INTEGER`, and `ALTER TABLE router_request_logs ADD COLUMN error_code TEXT`, then set `PRAGMA user_version=6` and commit. Verify all old columns/rows are unchanged; existing rows must keep NULL for the added fields. All deployed router databases need this out-of-band conversion before restart. No new `userdata/ai_router.lua` configuration fields are required.
- Before upgrading schema 4, stop and back up as above, create only `router_request_logs` and its index using the current definitions above, then set `PRAGMA user_version=6` and commit. Verify that pre-existing tables/rows are unchanged. Request history starts empty; do not fabricate rows from aggregates.
- Before upgrading schema 3, stop the router and back up SQLite consistently (including WAL). Convert out of band: rename `router_subscriptions` to `router_channels`, `router_subscription_windows` to `router_channel_windows`, its `subscription_id` column to `channel_id`, and `router_usage_models.subscription` to `channel`. Replace `router_usage_subscription_bucket` with `router_usage_channel_bucket(channel, bucket)` and set `user_version=4`. Preserve all row values, hashes, credentials, grants, aliases and historical usage.
- Older schemas first need removal of priority/threshold fields and qualification of targets/grants. Resolve ambiguous old names explicitly rather than choosing a channel silently; never relabel usage history as if requests originally used qualified names.
- Production router configs (`userdata/ai_router.lua` or the configured path) should remove obsolete `cooldown_seconds`/`unhealthy_cooldown` and `staleness`. Management clients must stop sending priority/thresholds; inference clients must use qualified names or explicit aliases. These environment-specific changes are not performed automatically by deployment.

## Verification

- Native Responses tests cover endpoint isolation, grants, state/affinity validation, aliases/redirects, reasoning/tool items, cache usage, error pass-through, quota refresh and downstream failures. Tests assert that neither endpoint calls another channel after any failure, before or after streaming begins.
- OpenAI clients use native Responses; GLM/compat use Chat Completions. Both require qualified concrete model names. Full stored/background/WebSocket Responses support remains out of scope, as documented in `../openai/spec.md`.

- Monitor tests verify that quota snapshots live only in memory, survive catalog reloads but not process restarts, and never read or overwrite legacy database snapshots. Failed polls preserve the current process's last-known values and original timestamps.
- The entrypoint starts polling via `UsageMonitor:startPolling`: detaching a coroutine alone does not execute it. The loop is explicitly resumed and checks due channels every five seconds. Scheduler-driven tests verify the initial poll and subsequent polls after an upstream failure.

- `Router_test` covers qualified resolution, identical model suffixes on different channels, redirects, embedded slashes, disabled targets, invalid aliases/configs and rejection of removed monitoring thresholds.
- Adapters are tested with fake HTTP streams and schedulers for validation, usage accounting and SSE fidelity.
- `UsageMonitor` tests cover fake upstream responses, aggregate-driven local estimates and in-memory snapshot lifetime.
- Repos and database initialization are tested like `ai.openai.storage` (`RouterDatabase_test.lua`), including rejection of the old schema without modifying its rows or columns.
- Request-log tests cover individual metadata persistence, safe combined filters, stable pagination with new inserts, age/count retention, booleans/numeric SQLite normalization, both protocols, JSON/SSE, local/upstream/post-commit errors, 499 cancellation, secret non-disclosure, write-failure isolation and authenticated read-only escaped HTML.
- Timing tests use deterministic clocks and verify ignored metadata/empty events, first-output stability, reasoning/tool deltas, native lifecycle events, missing/zero timing, speed eligibility, both protocols and no metrics for JSON. Error tests cover local validation, protocol/model rejection, upstream auth/rate/transport timeout, native failed responses, disconnect precedence, closed categories and schema-5 rejection without changing history.
- Probe tests exercise MCP discovery/annotations and strict schemas, all three provider kinds, explicit selection, redirects, one call only, fixed bodies, quota-consuming diagnostic semantics, sanitized timeout/auth/exception results, per-channel concurrency guard cleanup and absence from user statistics/request history. Compact-table tests cover hidden redundant upstream names, alias details, combined protocol/transport and escaped HTML.
- Admin pages are tested for login/logout CSRF, read-only boundaries, secret/code non-disclosure, merged channel quotas/freshness/reset details, local estimates, unprefixed model/redirect rows, absent upstream suffixes and legacy page redirects. Management and device-login behavior are covered by MCP tests.
- `McpTools_test` uses the native `mcp.Client` over real loopback sockets: initialization/discovery, dedicated-token and Origin enforcement, schema rejection, user key revocation without provider reload, transaction rollback, config patch credential preservation, disabled creation, catalog/alias validation, OAuth status/pending guards, usage and status, and committed reload failures with saved payloads and non-replaying recovery.
- Run with `./test aqua/ai/router`.
- `Server_test` covers single-channel errors for 401/429/5xx/transport failures, role-only chunks, informational quotas, sanitized exceptions, slot cleanup, user-limit overrides/key rotation, terminal-write accounting, real loopback upstream timeouts and downstream cancellation. Shared client tests cover coalesced SSE terminal/cancellation boundaries and exception cleanup.
- Also run `./test aqua/mcp` and `./luajit aqua/ai/router/smoke.lua`.

## Future Work and Open Questions

- Optional `/v1/embeddings`.
- Per-user token budgets or spend caps in addition to model grants.
- Rate-limit response headers (`x-ratelimit-*`) derived from window state.
- Admin audit log of configuration changes.
