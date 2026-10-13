## Goal

Provide reusable OpenAI-compatible Chat Completions and Responses clients backed by a ChatGPT subscription, plus an agent loop, without depending on application-specific models, tools, configuration, or UI.

## User Experience

- Applications can send a conversation to an OpenAI-compatible provider and receive either an assistant response or function-tool calls.
- Applications can register local tools and let the agent repeat the request/tool/result cycle until it produces a final answer.
- Applications can observe each complete tool call before execution and its matching result afterward, including whether execution reported an error.
- Applications can opt into a browser-based ChatGPT subscription login with a PKCE loopback callback and use the Codex Responses compatibility backend.
- Operators can run a small authenticated Responses-only HTTP proxy backed by one ChatGPT subscription, with direct JSON or typed SSE responses. The standalone proxy no longer accepts Chat Completions.
- Transport, provider, JSON, and tool failures are returned as useful errors instead of escaping into the application loop.

## Architecture Decisions

- `Client` owns only the `/chat/completions` protocol: request encoding, authentication headers, response decoding, and response-shape validation.
- `ChatCompat` owns the pure Chat Completions compatibility translation still used by `ai.router`: request validation and normalization into `ProxyRequestOptions` (including legacy functions, prompt caching, tool choice, and structured output), assistant result shaping, streaming delta construction, and the reasoning-effort/verbosity allowlists. Its types and unit tests live with the helper. The standalone `ProxyServer` does not import or execute it; model allowlisting stays with the caller.
- `SubscriptionAuth` owns the reusable PKCE authorization, callback-state validation, token refresh, and credential mutation. HTTP requests, scheduling, browser opening, credential persistence, and time are injected.
- `SubscriptionClient` translates common agent messages and function tools to the Responses input protocol. It also transports native Responses requests without translating their tools, input items, or typed events. It assembles output from typed SSE events and retains provider-owned output items, including encrypted reasoning, across stateless tool rounds.
- The HTTP request function is injected. The common layer does not create a scheduler or depend on `rizu.net.NetworkService`.
- `Agent` owns the reusable tool-calling loop. Tools provide an OpenAI function schema and a Lua handler; application-specific tool implementations remain outside `aqua`.
- `Agent` exposes paired `on_tool_call` and `on_tool_result` lifecycle callbacks. The result callback carries the execution-error state for presentation and tracing while the ordinary tool message retains the provider-compatible text content.
- `Agent:setClient()` changes the completion backend only when coordinated by the application; the common agent does not decide how provider/model selection affects conversation history.
- `Client:completeStream()` implements Chat Completions server-sent events without changing the existing complete-response API. It emits text deltas while assembling one protocol-valid assistant message, including fragmented tool call IDs, names, and JSON arguments.
- `ProxyServer` exposes `GET /v1/models`, `GET /v1/usage`, and `POST /v1/responses`, alongside the usage dashboard/history. It forwards native Responses as JSON or typed SSE events, authenticates callers against named bearer tokens from a Lua config, and can redirect an allowlisted public model name to a different upstream model. `POST /v1/chat/completions` returns 404 without creating an upstream client or recording inference usage.
- Each proxy request creates its own `SubscriptionClient`, so concurrent requests do not share cancellation or response-assembly state. The subscription authentication object and refreshed credentials remain shared, with access and refresh checks serialized to avoid racing refresh-token rotation. The serialization guard always releases its lock when authentication raises, so one failed refresh cannot block later requests indefinitely.
- Native Responses streaming starts downstream SSE headers on the first upstream event; no synthetic assistant-role chunk or Chat Completions terminal marker is generated.
- `ProxyNetwork` applies the same SOCKS5 domain whitelist and blacklist semantics as the game network service. The standalone entrypoint loads ignored `userdata/network.lua`, so subscription inference and OAuth refresh requests follow the user's existing route without copying proxy credentials.
- The client owns at most one active stream. `cancel()` closes that stream and causes the pending completion to return a cancellation error. Subscription request timeouts are end-to-end deadlines measured from the start of authentication, not independently reset idle timeouts for every upstream chunk. A failed downstream SSE write aborts and closes the active subscription stream.
- Assistant messages containing `tool_calls` are preserved in conversation history. Each tool result is appended with role `tool` and the matching `tool_call_id` before the next completion request.
- Applications may observe failed tool calls through `on_tool_failure`, including malformed calls, unknown tools, invalid arguments, execution exceptions, invalid results, and explicit tool error returns.

## Invariants

- Tool arguments are untrusted JSON. The agent validates that they decode to an object before invoking a handler.
- Unknown tools and tool failures become tool results so the model can recover; they do not crash the agent loop.
- The number of consecutive tool rounds is bounded.
- Provider response tables are not exposed until the required `choices[1].message` shape has been validated.
- Streaming input is parsed incrementally because SSE records and JSON payloads may cross arbitrary transport chunk boundaries.
- Chat Completions subscription streams ignore coalesced events after terminal completion, parse errors, or downstream callback cancellation. Exceptions during upload, header/body reads, parsing, or callbacks close the active stream, clear its reference, and return a sanitized upstream error.
- Responses text, refusal, and function-call arguments are assembled from typed incremental events. A terminal response with an empty output array must not discard already assembled output items.
- Native Responses requests are stateless: the proxy forces `store = false`, rejects server-managed response state and background execution, and always consumes the subscription backend as SSE. Public string input is normalized to the private backend's required input-item array.
- Native Responses streaming preserves typed event objects and emits matching SSE `event` and `data` fields without a Chat Completions `[DONE]` sentinel. Non-streaming requests return the terminal Response object assembled from the same event stream.
- Native Responses requests automatically include encrypted reasoning so Responses-native agents can return provider-owned reasoning items on later stateless tool rounds. Caller-supplied include values, tools, tool selection, parallel-call control, instructions, structured text options, reasoning settings, and other provider fields remain intact.
- Native Responses preserve provider output items, refusals, function calls, encrypted reasoning, status, and incomplete details without converting them into assistant messages or finish reasons.
- The shared `SubscriptionClient:completeStream` / `ChatCompat` path (used outside the standalone proxy) still maps output limits to `finish_reason = length`, refusals to assistant text, and modern/legacy function calls to Chat Completions shapes. Its compatibility tests remain in `ChatCompat_test.lua` and `SubscriptionClient_test.lua`.
- `[DONE]` terminates a successful stream. A closed stream without `[DONE]` is an error unless it was explicitly canceled.
- Proxy model names are allowlisted. `model_redirects` may map one configured public model name to a non-empty upstream model name; redirect sources must be in that allowlist. `GET /v1/usage` returns the upstream ChatGPT Codex usage object without reshaping it, and must never include subscription credentials. Proxy request logs contain the configured user, remote address, method, path, status, duration, effective model, affinity source, a truncated SHA-256 session fingerprint, and provider-reported input/cached token counts plus cache percentage. Raw session identifiers, prompts, responses, client bearer tokens, and subscription credentials are never logged; unavailable usage is shown as `-`.
- Every upstream request has a unique `x-client-request-id`. The proxy preserves a validated downstream cache-affinity identifier from `x-session-affinity`, `session_id`, or `x-client-request-id` (in that priority order) as the upstream `session_id`; when no affinity header is present, the SHA-256 digest of `prompt_cache_key` provides the same stable affinity without copying arbitrary request-body bytes into a header. Affinity and request identity remain separate: the stable session routes repeated prefixes to the same cache shard, while provider failures still report the unique request ID. Provider failures return the bounded `x-request-id` when available, or that client request ID as a troubleshooting fallback.
- Proxy request bodies require exactly one `Content-Length`; transfer encoding and duplicate lengths are rejected before the body is buffered. Header, request-body, upstream-response, global connection, per-user concurrency, and per-user request-rate limits are enforced independently.
- Native Responses usage remains in `usage.input_tokens`, `usage.output_tokens`, and `usage.input_tokens_details.cached_tokens`, including inside terminal SSE events; it is never converted into Chat Completions usage chunks.
- A Responses request may set `reasoning.effort` and `text.verbosity` to override proxy defaults. The proxy validates basic container types, not the compatibility helper's effort allowlist; model-specific support is determined upstream.
- The proxy forwards native `prompt_cache_key`, `prompt_cache_options`, content breakpoints, tools, tool choice, parallel-call control, and `text.format` without Chat Completions normalization. Cache keys still receive local header-safety validation and stable affinity derivation. Unsupported native provider options are reported by the backend, not silently downgraded.
- The current subscription backend rejects newer explicit-cache fields, sampling controls, and `max_output_tokens`. Existing subscription transport adaptation remains: `store=false`, upstream SSE, string-input normalization, encrypted-reasoning inclusion, default reasoning/text settings, and omission of `max_output_tokens`. Responses-only does not mean byte-for-byte passthrough or support for every public OpenAI API feature.
- The shared compatibility helper still translates Chat Completions content parts and controls for router consumers; removing the standalone endpoint does not change those consumers or the reusable `Client` and `Agent` APIs.
- The public Responses request schema currently documents text, image, and file message content but not `input_audio`. Audio is forwarded as a compatibility extension and can still be rejected by the ChatGPT subscription backend or selected model.

## Compatibility Progress

The standalone proxy targets Responses-native agent clients using the ChatGPT Codex Responses backend upstream. The router's existing Chat Completions path is unchanged in this first step.

| Feature | Status | Notes |
| --- | --- | --- |
| Chat Completions endpoint | Removed | `/v1/chat/completions` returns 404; use `/v1/responses`. |
| Function tools and tool choice | Implemented | Includes forced functions and parallel calls. |
| Incremental tool-call streaming | Implemented | Native output-item and function-call argument events are relayed. |
| Reasoning effort and summaries | Implemented | Native `reasoning` settings, reasoning items and summary events. |
| Response verbosity | Implemented | `low`, `medium`, and `high` map to Responses `text.verbosity`. |
| Structured output | Implemented | Supports text, JSON object, and JSON Schema formats. |
| Multimodal input | Implemented | Native Responses content is preserved; model/backend support still applies. |
| Prompt caching | Partial; upstream blocked | Cache keys and affinity are preserved. Newer explicit cache options are forwarded but the current subscription backend rejects them. |
| Direct `/v1/responses` | Implemented | Stateless HTTP and typed SSE, including native parallel tool-call round trips. Server-managed state, background mode, and WebSocket transport are not supported. |
| Upstream error fidelity | Implemented | Returns bounded provider status, code, message, and request ID without logging prompts or credentials. |
| Optional generation parameters | Backend-dependent | Native fields are forwarded, except the existing `max_output_tokens` omission. |
| Response state | Native | Provider status, incomplete details, output items and typed events are preserved. |
| Legacy function aliases | Not exposed | Use native Responses function tools and input items. |

## Standalone Proxy

### Responses-only client migration

Clients of this proxy must select the Responses protocol and use `POST /v1/responses`, replacing `messages` with native `input`/`instructions`, `reasoning_effort` with `reasoning.effort`, and `response_format` with `text.format`. Send native function-call/output items and provider reasoning items on stateless follow-up rounds. Chat Completions-only clients must use another endpoint; the proxy no longer translates them. Existing bearer tokens, model redirects, affinity headers, usage database, and config field names remain unchanged. No production configuration migration is required, but production clients must switch protocol before deploying this breaking endpoint removal. Do not delete their history database.

Copy `aqua/ai/openai/proxy_config.example.lua` to the ignored `userdata/ai_proxy.lua` and replace the client access token. The proxy can create `userdata/ai_auth.lua`; sign in from the repository root before starting the service:

```bash
./luajit aqua/ai/openai/proxy.lua login
```

Device authorization is the default login for both local and headless servers. The command prints a verification URL and one-time code, polls for approval for at most 15 minutes, and atomically saves the resulting access and refresh credentials. The code must only be entered when the operator initiated the login from this proxy. If device authorization is unavailable, use the loopback PKCE flow:

```bash
./luajit aqua/ai/openai/proxy.lua login-browser
```

Browser login listens only on `127.0.0.1:1455`. When running the proxy through SSH, forward that port before starting `login-browser`, for example with `ssh -L 1455:127.0.0.1:1455 <server>`. Then start the service:

```bash
./luajit aqua/ai/openai/proxy.lua
```

An alternate config path can be passed as the first argument when serving or after the login command, for example `proxy.lua login userdata/other_proxy.lua`. To redirect a public model request to another upstream model, add a `model_redirects` map to that config:

```lua
model_redirects = {
	["gpt-5.6-sol"] = "gpt-5.6-terra",
}
```

The map source must appear in `models`; it remains the public allowlisted name, while the map target is sent upstream. Usage history, dashboard model totals, and `model_prices` use that upstream target, so configure pricing under `gpt-5.6-terra` in this example. The default listener is loopback-only at `http://127.0.0.1:28081/v1`; the usage dashboard is at `http://127.0.0.1:28081/usage`. The dashboard itself is public so a browser can open it normally, but it only fetches usage after the operator enters a configured proxy bearer token. That token is kept in `sessionStorage`, not embedded in the page or persisted across browser sessions. The entrypoint refuses placeholder or shorter-than-32-character client tokens. The service loads subscription OAuth credentials from ignored `userdata/ai_auth.lua`, loads SOCKS5 routing from ignored `userdata/network.lua`, verifies upstream TLS against the repository CA bundle, and atomically persists login and refreshed credentials. Serving without an access or refresh credential fails with a command showing how to log in.

For public access, keep the Lua server bound to `127.0.0.1` and terminate HTTPS at Nginx using `nginx_proxy.example.conf` as a starting point. The example exposes authenticated `/v1/` routes; expose `/usage` separately if the dashboard is needed remotely. The Lua and Nginx request-body limits must match; the 16 MiB default accommodates long stateless agent conversations while retaining a finite memory bound. Replace its hostname and certificate paths before enabling it; do not expose port `28081` through a firewall or container port mapping.

## Proxy History

- `/usage` shows a per-second reset countdown and hourly request/input-token/output-token charts for 24 or 168 buckets, including the current partial hour. Views switch between totals and named clients; a table includes errors and the number of requests with estimated counts.
- Authenticated `GET /v1/usage/history` returns `bucket_seconds`, `first_bucket`, `last_bucket`, `generated_at`, `model_redirects`, and `rows`. `model_redirects` maps each configured public model name to the model actually sent upstream, allowing the dashboard to show active redirects. Each row has `bucket`, `client`, `model`, `requests`, `errors`, `input_tokens`, `cached_input_tokens`, `output_tokens`, `estimated_requests`, `cost_usd`, and `cache_savings_usd`; the response also declares `currency = "USD"`. Missing buckets mean zero. All configured bearer tokens can read all clients' statistics, including historical client names. `/v1/usage` remains unchanged.
- `UsageRepo` stores hourly aggregates in SQLite, keyed by UTC hour, configured client name, and the model actually sent upstream. Client and model tables sum input/output tokens, API-equivalent USD cost, and cache savings for the selected period. Cache share is the ratio of summed cached input to summed total input, not an average of row percentages; zero input displays an unavailable share. Savings are `cached_input_tokens * (input_price - cached_input_price) / 1e6`, relative to ordinary input pricing. Missing prices are zero; negative savings remain visible if configured cached rates exceed ordinary rates. Counts include historical/estimated input, so the displayed share can understate actual cache effectiveness. Names shared by multiple tokens merge; renamed clients start a new series. No prompts, responses, credentials, or addresses are persisted. History begins when this feature is enabled; old aggregate rows are retained, but only the latest 168 buckets are returned.
- Authenticated inference requests are counted at completion, including local rejection and upstream errors, but not usage/model/dashboard requests or authentication failures. Requests interrupted by process termination or unexpected handler exceptions are not recorded. Streaming and non-streaming requests are counted once using their assembled result.
- Provider input/output usage takes priority independently. Missing values use `ceil(JSON bytes / 4)` over request content/tool definitions or assembled output content/tool calls. This is a rough estimate, not a tokenizer; multimodal payloads and hidden reasoning cannot be estimated accurately. On failed streams, unavailable partial output is not counted. `estimated_requests` marks requests with at least one missing provider count, including failures with unknown counts.
- Following the `sea` storage pattern, `storage/UsageDatabase` owns connection lifecycle, WAL/NORMAL/busy-timeout settings, `TableOrm`, `Models`, and `SqliteMigrator` with `PRAGMA user_version`. `storage/db.sql` owns the schema, `storage/models/` owns ORM model definitions, and numbered `storage/migrations/` own schema changes. `UsageRepo` accepts `rdb.Models`, never creates or migrates tables, selects through the model (including numeric decoding), and uses one atomic SQL upsert through its ORM for additive counters. There is no dependency on `sea` itself.
- The standalone proxy opens `usage_db_path` (default `userdata/ai_proxy_usage.db`). Schema creation is automatic; the database survives restarts. New databases are initialized transactionally from `storage/db.sql` at version 1; legacy unversioned schemas are no longer migrated. Failed migrations roll back; databases from newer code versions are rejected. Storage operations are synchronous and aggregates keep write volume to one upsert per completed request.
- Model prices live in `model_prices = { ["model-name"] = {input = 2, cached_input = 0.2, output = 8} }` in the Lua proxy config, in USD per million tokens (example prices only). Omitted models or price fields cost zero. Prices must be finite and non-negative. Cost is calculated on read using current configured prices, including estimated tokens; it is not an upstream bill and excludes separately billed tools. Cost is `((input_tokens - cached_input_tokens) * input + cached_input_tokens * cached_input + output_tokens * output) / 1e6`. Cached input comes only from provider `usage.input_tokens_details.cached_tokens`; absent counts are zero, never estimated. Cached input is included in the input total, not added to it. An omitted cached-input price is zero like other omitted prices. The example config contains operator-provided reference rates, not independently verified current provider prices. Restart after editing prices.
- Legacy history migration was removed: a fresh database starts with empty model/client aggregates, including cache counters. Existing version-1 databases are preserved on restart.
- Deployment: the default filename changed from `userdata/ai_proxy_usage.sqlite3` to `userdata/ai_proxy_usage.db` so the database and journal sidecars match repository ignore rules. Stop the proxy before removing legacy database files and their journal sidecars to start fresh; this permanently discards history. Update `usage_db_path` in local/production `userdata/ai_proxy.lua` if explicitly configured. The new default creates an empty database when absent. To enable nonzero cost estimates, add `model_prices` there with your chosen `input`, `cached_input`, and `output` rates; without it all costs are zero. Ignored production configs must be updated separately; repository deployment does not copy the local `userdata/ai_proxy.lua`. Optionally set `usage_db_path` to a persistent writable location; its parent directory must exist and allow SQLite journal files. Preserve the database across deployments. Restart the proxy to enable collection and reload its cached dashboard.

## Future Work and Open Questions

- Audit compatibility against the public Responses API and maintain an explicit capability matrix. The current standalone proxy implements stateless creation over HTTP/typed SSE, not the complete API; forwarding a field does not prove backend support.
- Investigate backend support before adding stored-response retrieval/deletion, input-item listing, Conversations, `previous_response_id`, background execution, and background-response cancellation. Unsupported capabilities must remain explicit rather than being emulated as if native.
- Revisit the silent omission of `max_output_tokens`: support an upstream-enforced cap if available, or explicitly reject unsupported client-selected limits instead of implying they are honored.
- Audit native request adaptation (`store=false`, upstream SSE, string-input normalization, encrypted-reasoning inclusion, and reasoning/text defaults), distinguishing required subscription-backend constraints from avoidable changes to caller intent.
- Verify built-in tools, structured output, multimodal input, reasoning round trips, and cache options against the actual subscription backend and selected models; do not infer support from the public API or the local model allowlist.
- Add live Responses agent checks covering parallel function calls/results, encrypted-reasoning continuation, incomplete/failed responses, and downstream cancellation. Current live verification covers simple text JSON/SSE only; broader behavior is covered by unit tests, not a full live agent workflow.

- Consider a shared provider capability description for optional compatibility flags.
- Track compatibility changes to the ChatGPT Codex OAuth and Responses backend independently from the public API-key client.
- Add Responses WebSocket transport if an agent requires it.
- Revisit stored Responses, Conversations, `previous_response_id`, and background mode if the subscription backend exposes durable server-managed state.
- Codex currently requests a private model-catalog shape from custom Responses providers, while the proxy's standard OpenAI-compatible `/v1/models` route returns `data`. Codex falls back to its bundled model metadata, but this warning could be removed if Codex exposes a standard catalog mode or a safe way to disable provider catalog refresh.
