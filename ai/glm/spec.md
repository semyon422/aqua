## Goal

Provide a GLM Coding Plan Chat Completions client and a small authenticated proxy backed by one subscription API key, without depending on application-specific models, tools, configuration, or UI.

## User Experience

- Agents and other OpenAI Chat Completions clients can point at the proxy's `POST /v1/chat/completions` endpoint and use a GLM Coding Plan subscription upstream, both non-streaming and SSE streaming.
- Requests can opt into GLM-specific controls: `thinking` mode, `reasoning_effort`, and incremental `tool_stream` tool-call output.
- Streaming reasoning arrives as Chat Completions `delta.reasoning_content`, matching how GLM exposes reasoning summaries.
- Transport, provider, and JSON failures are returned as useful errors instead of escaping into the application loop.

## Architecture Decisions

- `Client` owns only the upstream `/chat/completions` protocol against a GLM Coding Plan endpoint (default `https://api.z.ai/api/coding/paas/v4`): request encoding, bearer authentication, response decoding, response-shape validation, SSE assembly, and one-active-stream cancellation. Unlike the OpenAI package there is no OAuth or Responses translation because the subscription is a plain API key speaking Chat Completions natively.
- The HTTP request and stream functions are injected. The client does not create a scheduler or depend on `rizu.net.NetworkService`.
- `Client:completeStream()` relays each raw upstream delta to a callback and assembles one assistant message with `content`, `reasoning_content`, fragmented `tool_calls`, the terminal `finish_reason`, and the last reported `usage`. Returning `false` from the callback aborts and cancels the upstream stream, which is how the proxy reacts to a closed downstream connection.
- `ProxyServer` is a single-endpoint server: only `POST /v1/chat/completions` is served. Model catalogs, usage dashboards, usage history, and a web frontend are intentionally out of scope for this package.
- The proxy rebuilds the upstream body from validated fields instead of forwarding the client body verbatim. Only the supported allowlist of Chat Completions fields reaches GLM; explicitly unsupported fields fail fast with `unsupported_parameter`.
- `developer` message history is normalized to `system` because the GLM Coding Plan endpoint does not document the developer role.
- `max_completion_tokens` and legacy `max_tokens` are both accepted, validated as mutually exclusive positive integers, and sent upstream as `max_tokens`.
- Streaming responses send SSE headers and the assistant-role chunk immediately after local request validation, before the upstream request starts. Upstream failures after that point are delivered as SSE `error` events followed by `[DONE]` under the already-committed HTTP 200.
- The proxy re-emits its own chunk IDs and echoes the public model name. Upstream `function_call` finish reasons are mapped to `tool_calls`; unknown upstream finish reasons become mid-stream errors instead of being silently rewritten.
- Reused shared infrastructure from the OpenAI package: `ai.openai.SseParser` for incremental SSE records and `ai.openai.ProxyNetwork` for SOCKS5 routing and TLS options. Both are protocol-agnostic.
- The standalone entrypoint loads ignored `userdata/glm_proxy.lua` and ignored `userdata/network.lua`, mirroring the OpenAI proxy layout, so upstream inference follows the user's existing route without copying proxy credentials.

## Invariants

- Proxy model names are allowlisted. `model_redirects` maps a configured public model name to a different upstream model; redirect sources must be in the allowlist.
- Request bodies require exactly one `Content-Length`; transfer encoding and duplicate lengths are rejected before the body is buffered. Header, global connection, per-user concurrency, and per-user rate limits are enforced independently.
- Proxy users authenticate with named bearer tokens of at least 32 characters; the GLM API key must be at least 32 characters and must not remain the documented placeholder.
- Provider response tables are not exposed until the required `choices[1].message` shape has been validated, in both streaming and non-streaming paths.
- Streaming input is parsed incrementally because SSE records and JSON payloads may cross arbitrary transport chunk boundaries. `[DONE]` terminates a successful stream; a closed stream without `[DONE]` is an error unless it was explicitly canceled.
- Tool arguments are untrusted JSON strings and are relayed and assembled verbatim; the proxy never parses or rewrites them.
- `stream_options` is validated but not forwarded upstream. GLM reports usage on the final stream chunk; the proxy emits a usage-only chunk with an empty `choices` array before `[DONE]` only when the client asked for `include_usage`.
- When `include_usage` is requested, every chunk carries `"usage": null` except the final usage chunk, matching OpenAI Chat Completions streaming shape.
- Upstream errors return the bounded provider status, type, code, and message without logging prompts, responses, client tokens, or the GLM API key. Proxy logs contain only the configured user name, remote address, method, path, status, and duration.
- Every upstream failure path releases the per-user concurrency slot before the handler error is re-raised.

## Standalone Proxy

Copy `aqua/ai/glm/proxy_config.example.lua` to the ignored `userdata/glm_proxy.lua` and replace `api_key` with a GLM Coding Plan key and the user `access_token` with a long random bearer token. Then start the service:

```bash
./luajit aqua/ai/glm/proxy.lua
```

An alternate config path can be passed as the first argument, for example `proxy.lua userdata/other_glm_proxy.lua`. The default listener is loopback-only at `http://127.0.0.1:28082/v1/chat/completions`. The entrypoint loads SOCKS5 routing from ignored `userdata/network.lua`, verifies upstream TLS against the repository CA bundle, and refuses placeholder keys and tokens. Optional config fields:

- `thinking = "enabled"|"disabled"` — default thinking mode applied when the request sets neither `thinking` nor `reasoning_effort`.
- `tool_stream = true|false` — whether tool-bearing requests ask GLM for incremental tool-call streaming (default `true`).
- `model_redirects` — map a public model name to a different upstream model, for example `["glm-5.3-flash"] = "glm-5.3"`.

For public access, keep the Lua server bound to `127.0.0.1` and terminate HTTPS at Nginx using `aqua/ai/openai/nginx_proxy.example.conf` as a starting point with the port and zone names adjusted.

## Future Work and Open Questions

- A usage dashboard and usage history similar to the OpenAI proxy could be added if the GLM Coding Plan exposes a usage endpoint.
- A `GET /v1/models` endpoint could be added when more than one consumer needs model discovery.
- GLM vision and audio content parts are currently rejected during normalization; revisit when a coding-plan model documents multimodal input.
- Revisit the finish reason allowlist when GLM documents new terminal reasons such as quota or safety stop codes.
