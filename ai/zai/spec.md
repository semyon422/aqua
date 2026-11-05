## Goal

Provide a GLM Coding Plan Chat Completions client and a small authenticated proxy backed by one subscription API key, without depending on application-specific models, tools, configuration, or UI.

## User Experience

- Agents and other OpenAI Chat Completions clients can point at the proxy's `POST /v1/chat/completions` endpoint and use a GLM Coding Plan subscription upstream, both non-streaming and SSE streaming.
- Authenticated clients can read the GLM Coding Plan usage monitor through `GET /v1/usage`, which returns the current plan level and per-window quota usage without exposing the GLM API key.
- Authenticated clients can list the configured public models through `GET /v1/models`; redirect sources keep their public names and redirect targets stay private.
- Requests can opt into GLM-specific controls: `thinking` mode, `reasoning_effort`, and incremental `tool_stream` tool-call output.
- Streaming reasoning arrives as Chat Completions `delta.reasoning_content`, matching how GLM exposes reasoning summaries.
- Transport, provider, and JSON failures are returned as useful errors instead of escaping into the application loop.

## Architecture Decisions

- `Client` is a thin GLM coding-plan facade over `ai.openai.ChatCompletionsClient`, retaining `complete(body)` (full completion), `completeStream(body, on_delta?)` (assembled assistant message), the required non-empty API key, the Z.ai error label, and existing `zai.*` type aliases. The shared raw-body transport owns encoding, bearer headers, response decoding/shape validation, SSE assembly, deadlines, bounded error reads and one-active-stream cancellation. The GLM endpoint defaults to `https://api.z.ai/api/coding/paas/v4` in the standalone wiring, not the client. Unlike the OpenAI subscription client there is no OAuth or Responses translation because GLM speaks Chat Completions natively.
- The HTTP request and stream functions and the required `get_time(): number` clock are injected. Both `Client` (through the shared raw transport) and `ProxyServer` reject missing/non-function clocks, with no direct `require("socket")` dependency or fallback. Standalone wiring supplies `scheduler.get_time`; callers must explicitly supply seconds (fractional precision recommended, Unix epoch seconds for proxy accounting). No new runtime config field is needed. The client does not create a scheduler or depend on `rizu.net.NetworkService`.
- `Client:completeStream()` relays each raw upstream delta to a callback and assembles one assistant message with `content`, `reasoning_content`, fragmented `tool_calls`, the terminal `finish_reason`, and the last reported `usage`. Returning `false` from the callback aborts and cancels the upstream stream, which is how the proxy reacts to a closed downstream connection.
- `Protocol` owns pure GLM request validation/normalization: message/tool schemas, supported parameter checks, thinking/structured-output controls, model redirects and defaults. Both the standalone `ProxyServer` and the external router's Z.ai adapter call `ai.zai.Protocol` directly; adapters no longer load an HTTP server to normalize a request. The old `ProxyServer.normalizeMessages`/`normalizeTools`/`normalizeRequest` helpers moved to `Protocol` with the same signatures and return values.
- Chat Completions SSE payloads are built by the shared pure `ai.openai.ChatCompletionsProtocol` (`chunk`/`usageChunk`); HTTP writes, GLM's strict finish-reason allowlist and the standalone proxy's commit/error policy remain local. Native Responses is not translated.
- `ProxyServer` serves `POST /v1/chat/completions`, `GET /v1/models`, and `GET /v1/usage`. The usage route calls an injected `fetch_usage` function so the server stays free of HTTP-client wiring. Usage dashboards, usage history, and a web frontend are intentionally out of scope for this package.
- The standalone entrypoint and router share `UsageClient.fetch(options)` for `https://api.z.ai/api/monitor/usage/quota/limit` (override with the injected `url`; standalone/router wiring preserves `usage_url`). The caller supplies the HTTP request function and Coding Plan API key, so inference and monitoring retain the same external SOCKS5/TLS policy. The client makes one bearer-authenticated GET, optionally forwards a timeout to the request function, validates JSON object containers and unwraps only `data`. It has no scheduler, clocks, auth storage, retries, window parsing or application imports. No web-session JWT, cookies, or `bigmodel-*` headers are required.
- HTTP failures return shared `openai.UsageFetchError` metadata with actual upstream status, fixed safe message/type and `upstream_http`; transport/invalid-response failures have no fabricated HTTP status. Raw provider bodies and JSON decoder diagnostics are not copied into metadata. The optional second error return can retain an injected transport error; callers must not expose it. Exceptions remain the caller boundary's responsibility. The standalone usage endpoint now preserves actual upstream HTTP statuses instead of the entrypoint's old blanket 502 and uses the shared `upstream_http` code; failures without an upstream status retain generic 502 output. Successful `/v1/usage` payloads remain unchanged.
- The upstream monitor response is a z.ai RPC envelope; `fetchUsage` returns its `data` object (`limits` and `level`) without reshaping. Observed `limits` entries are `CREDIT_LIMIT` rows where `unit = 3, number = 5` is the 5-hour window and `unit = 6, number = 1` is the rolling weekly window; `usage` is the quota, `currentValue` the consumption, `percentage` the integer used-percent, and `nextResetTime` an epoch timestamp in milliseconds.
- `UsageProtocol.parseWindows(data)` independently decodes the already-unwrapped monitor `data` object into shared `openai.UsageWindows`: `(unit=3, number=5)` maps to `five_hour`, `(6,1)` to `weekly`; `percentage`, `currentValue` and `usage` become `used_percent`, `used_tokens` and `quota_tokens`, while `nextResetTime` is floored from epoch milliseconds to seconds. Unknown/malformed rows are ignored; repeated recognized rows retain the previous last-row-wins behavior. Only finite numeric fields are retained (no numeric-string coercion, clamping, derived percentages or missing-count estimates). Empty/partial results are allowed so callers can decide which windows are required. This pure module has no HTTP, router, database or clock dependency and never mutates input or unwraps the RPC envelope. Polling, snapshot freshness, local estimates and diagnostics stay in the router; standalone `/v1/usage` continues returning raw `data` unchanged.
- The proxy rebuilds the upstream body from validated fields instead of forwarding the client body verbatim. Only the supported allowlist of Chat Completions fields reaches GLM; explicitly unsupported fields fail fast with `unsupported_parameter`.
- `developer` message history is normalized to `system` because the GLM Coding Plan endpoint does not document the developer role.
- `max_completion_tokens` and legacy `max_tokens` are both accepted, validated as mutually exclusive positive integers, and sent upstream as `max_tokens`.
- Streaming responses send SSE headers and the assistant-role chunk immediately after local request validation, before the upstream request starts. Upstream failures after that point are delivered as SSE `error` events followed by `[DONE]` under the already-committed HTTP 200.
- The proxy re-emits its own chunk IDs and echoes the public model name. Upstream `function_call` finish reasons are mapped to `tool_calls`; unknown upstream finish reasons become mid-stream errors instead of being silently rewritten.
- Reused shared infrastructure from the OpenAI package: `ai.openai.ChatCompletionsClient` for transport/lifecycle, its incremental `SseParser`, and `ai.openai.ProxyNetwork` for SOCKS5 routing and TLS options. Generic compatible endpoints use the raw client directly and do not depend on this GLM facade or need a placeholder API key.
- The standalone entrypoint loads ignored `userdata/zai_proxy.lua` and ignored `userdata/network.lua`, mirroring the OpenAI proxy layout, so upstream inference follows the user's existing route without copying proxy credentials.

## Invariants

- Proxy model names are allowlisted. `model_redirects` maps a configured public model name to a different upstream model; redirect sources must be in the allowlist.
- Request bodies require exactly one `Content-Length`; transfer encoding and duplicate lengths are rejected before the body is buffered. Header, global connection, per-user concurrency, and per-user rate limits are enforced independently.
- Proxy users authenticate with named bearer tokens of at least 32 characters; the GLM API key must be at least 32 characters and must not remain the documented placeholder.
- Provider response tables are not exposed until the required `choices[1].message` shape has been validated, in both streaming and non-streaming paths.
- Streaming input is parsed incrementally because SSE records and JSON payloads may cross arbitrary transport chunk boundaries. `[DONE]` terminates a successful stream; a closed stream without `[DONE]` is an error unless it was explicitly canceled.
- Terminal completion, a streaming error, or callback cancellation stops processing remaining events in the same transport chunk. Streaming exceptions close the active stream, clear its reference, and return a sanitized error. Non-JSON HTTP error bodies still return provider error metadata with the original HTTP status.
- A configured streaming timeout is a total deadline from before connection through upload, headers, and reads; arriving chunks do not reset it. This tightens the previous idle-timeout behavior without adding configuration fields. Tests inject `get_time` to check deadline behavior deterministically.
- Streaming HTTP error bodies are read incrementally under the same deadline and bounded to 64 KiB. Oversized or undecodable error bodies produce a generic message while preserving the HTTP status.
- Tool arguments are untrusted JSON strings and are relayed and assembled verbatim; the proxy never parses or rewrites them.
- `stream_options` is validated but not forwarded upstream. GLM reports usage on the final stream chunk; the proxy emits a usage-only chunk with an empty `choices` array before `[DONE]` only when the client asked for `include_usage`.
- When `include_usage` is requested, every chunk carries `"usage": null` except the final usage chunk, matching OpenAI Chat Completions streaming shape.
- Upstream errors return the bounded provider status, type, code, and message without logging prompts, responses, client tokens, or the GLM API key. Proxy logs contain only the configured user name, remote address, method, path, status, and duration.
- `GET /v1/models` returns the configured public model allowlist with `owned_by = "zai-coding-plan"`; it never includes `model_redirects` targets. It and `GET /v1/usage` require proxy authentication, return upstream or configured data without reshaping, and must never include the GLM API key or other credentials. They do not consume request-rate or concurrency limits; only inference requests consume them.
- Every upstream failure path releases the per-user concurrency slot before the handler error is re-raised.

## Standalone Proxy

Copy `aqua/ai/zai/proxy_config.example.lua` to the ignored `userdata/zai_proxy.lua` and replace `api_key` with a GLM Coding Plan key and the user `access_token` with a long random bearer token. Then start the service:

```bash
./luajit aqua/ai/zai/proxy.lua
```

An alternate config path can be passed as the first argument, for example `proxy.lua userdata/other_zai_proxy.lua`. The default listener is loopback-only at `http://127.0.0.1:28082/v1/chat/completions`. `GET /v1/usage` is served on the same listener and returns the monitor `data` object; override `usage_url` in the config when `base_url` points at a different API host. `GET /v1/models` lists the configured public models. The entrypoint loads SOCKS5 routing from ignored `userdata/network.lua`, verifies upstream TLS against the repository CA bundle, and refuses placeholder keys and tokens. Optional config fields:

- `thinking = "enabled"|"disabled"` — default thinking mode applied when the request sets neither `thinking` nor `reasoning_effort`.
- `tool_stream = true|false` — whether tool-bearing requests ask GLM for incremental tool-call streaming (default `true`).
- `model_redirects` — map a public model name to a different upstream model, for example `["glm-5.3-flash"] = "glm-5.3"`.

For public access, keep the Lua server bound to `127.0.0.1` and terminate HTTPS at Nginx using `aqua/ai/openai/nginx_proxy.example.conf` as a starting point with the port and zone names adjusted.

## Tests

- `UsageClient_test.lua` covers required bearer headers, default/custom monitor endpoints and timeout forwarding, raw-data unwrapping/preservation, actual HTTP status and safe metadata, transport/no-retry behavior and rejection of malformed JSON/envelopes or non-object data. `ProxyServer_test.lua` also exercises this shared client through the authenticated usage route, checking HTTP status preservation, generic local-error 502 responses and absence of upstream/transport secrets.
- `UsageProtocol_test.lua` covers recognized/unknown unit-number pairs, quota/consumption fields, millisecond conversion, partial/zero/over-quota windows, duplicate rows, malformed roots/containers/rows, invalid/non-finite fields, non-mutation and the unwrapped-data boundary.
- `ai/openai/ClockInjection_test.lua` covers mandatory clock validation and exact injected-clock retention for the GLM facade and proxy as well as OpenAI clients.
- `Protocol_test.lua` exercises normalization without a listener: redirects/defaults, text parts and developer role conversion, tools/opaque arguments, thinking/structured output, stream usage preferences, unsupported parameters, malformed and multimodal history, and absence of input mutation.
- `Client_test.lua` checks the GLM facade's required key, Z.ai HTTP error label, full completion return value and full-delta callback contract. Shared streaming/cancellation/deadline/error-read regressions moved to `ai/openai/ChatCompletionsClient_test.lua`, where they exercise the same inherited implementation, including cancellation inside a callback or during a read/open and subsequent client reuse. `ProxyServer_test.lua` retains HTTP authentication/validation, usage-frame and error-contract coverage; shared payload/usage tests live in `ai/openai/ChatCompletionsProtocol_test.lua`.

## Future Work and Open Questions

- A usage dashboard and usage history similar to the OpenAI proxy could be built on top of the monitor endpoint.
- Confirm whether GLM hosts other than `api.z.ai` serve the same monitor path before relying on a derived `usage_url`.
- GLM vision and audio content parts are currently rejected during normalization; revisit when a coding-plan model documents multimodal input.
- Revisit the finish reason allowlist when GLM documents new terminal reasons such as quota or safety stop codes.
