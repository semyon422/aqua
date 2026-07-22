## Goal

Provide reusable OpenAI-compatible Chat Completions and ChatGPT subscription clients plus an agent loop, without depending on application-specific models, tools, configuration, or UI.

## User Experience

- Applications can send a conversation to an OpenAI-compatible provider and receive either an assistant response or function-tool calls.
- Applications can register local tools and let the agent repeat the request/tool/result cycle until it produces a final answer.
- Applications can opt into a browser-based ChatGPT subscription login with a PKCE loopback callback and use the Codex Responses compatibility backend.
- Operators can run a small authenticated OpenAI-compatible HTTP proxy backed by one ChatGPT subscription.
- Transport, provider, JSON, and tool failures are returned as useful errors instead of escaping into the application loop.

## Architecture Decisions

- `Client` owns only the `/chat/completions` protocol: request encoding, authentication headers, response decoding, and response-shape validation.
- `SubscriptionAuth` owns the reusable PKCE authorization, callback-state validation, token refresh, and credential mutation. HTTP requests, scheduling, browser opening, credential persistence, and time are injected.
- `SubscriptionClient` translates common agent messages and function tools to the Responses input protocol. It assembles output from typed SSE events and retains provider-owned output items, including encrypted reasoning, across stateless tool rounds.
- The HTTP request function is injected. The common layer does not create a scheduler or depend on `rizu.net.NetworkService`.
- `Agent` owns the reusable tool-calling loop. Tools provide an OpenAI function schema and a Lua handler; application-specific tool implementations remain outside `aqua`.
- `Agent:setClient()` changes the completion backend only when coordinated by the application; the common agent does not decide how provider/model selection affects conversation history.
- `Client:completeStream()` implements Chat Completions server-sent events without changing the existing complete-response API. It emits text deltas while assembling one protocol-valid assistant message, including fragmented tool call IDs, names, and JSON arguments.
- `ProxyServer` exposes `GET /v1/models` and `POST /v1/chat/completions`, translates subscription results back to Chat Completions JSON or SSE, and authenticates callers against named bearer tokens from a Lua config.
- Each proxy request creates its own `SubscriptionClient`, so concurrent requests do not share cancellation or response-assembly state. The subscription authentication object and refreshed credentials remain shared, with access and refresh checks serialized to avoid racing refresh-token rotation.
- `ProxyNetwork` applies the same SOCKS5 domain whitelist and blacklist semantics as the game network service. The standalone entrypoint loads ignored `userdata/network.lua`, so subscription inference and OAuth refresh requests follow the user's existing route without copying proxy credentials.
- The client owns at most one active stream. `cancel()` closes that stream and causes the pending completion to return a cancellation error.
- Assistant messages containing `tool_calls` are preserved in conversation history. Each tool result is appended with role `tool` and the matching `tool_call_id` before the next completion request.
- Applications may observe failed tool calls through `on_tool_failure`, including malformed calls, unknown tools, invalid arguments, execution exceptions, invalid results, and explicit tool error returns.

## Invariants

- Tool arguments are untrusted JSON. The agent validates that they decode to an object before invoking a handler.
- Unknown tools and tool failures become tool results so the model can recover; they do not crash the agent loop.
- The number of consecutive tool rounds is bounded.
- Provider response tables are not exposed until the required `choices[1].message` shape has been validated.
- Streaming input is parsed incrementally because SSE records and JSON payloads may cross arbitrary transport chunk boundaries.
- Responses text, refusal, and function-call arguments are assembled from typed incremental events. A terminal response with an empty output array must not discard already assembled output items.
- `[DONE]` terminates a successful stream. A closed stream without `[DONE]` is an error unless it was explicitly canceled.
- Proxy model names are allowlisted. Proxy logs contain only the configured user name, remote address, method, path, status, and duration; prompts, responses, client tokens, and subscription credentials are never logged.
- Proxy request bodies require exactly one `Content-Length`; transfer encoding and duplicate lengths are rejected before the body is buffered. Header, request-body, upstream-response, global connection, per-user concurrency, and per-user request-rate limits are enforced independently.
- When a streaming request sets `stream_options.include_usage`, the proxy maps Responses token counts to Chat Completions usage fields and emits the final usage-only chunk with an empty `choices` array before `[DONE]`. Non-streaming completions include the same usage object when upstream reports it.
- A Chat Completions request may set `reasoning_effort` to override the proxy config for that request. Omitting it uses the configured default; invalid values fail before an upstream request is made.
- The proxy accepts `developer`, `system`, `user`, `assistant`, and `tool` messages plus function tools. Chat Completions user parts map to subscription Responses parts: `text` to `input_text`, `image_url` to `input_image`, `input_audio` remains `input_audio`, and `file` maps to `input_file`. Assistant `text` and `refusal` history is normalized to text. Unsupported or malformed content fails instead of being silently discarded.
- The public Responses request schema currently documents text, image, and file message content but not `input_audio`. Audio is forwarded as a compatibility extension and can still be rejected by the ChatGPT subscription backend or selected model.

## Standalone Proxy

Copy `aqua/ai/openai/proxy_config.example.lua` to the ignored `userdata/ai_proxy.lua`, replace the client access token, and start the service from the repository root:

```bash
./luajit aqua/ai/openai/proxy.lua
```

An alternate config path can be passed as the first argument. The default listener is loopback-only at `http://127.0.0.1:28081/v1`. The entrypoint refuses placeholder or shorter-than-32-character client tokens. The service loads subscription OAuth credentials from ignored `userdata/ai_auth.lua`, loads SOCKS5 routing from ignored `userdata/network.lua`, verifies upstream TLS against the repository CA bundle, and atomically persists refreshed credentials.

For public access, keep the Lua server bound to `127.0.0.1` and terminate HTTPS at Nginx using `nginx_proxy.example.conf` as a starting point. The example preserves Authorization, disables response buffering for SSE, buffers and bounds request bodies, and applies public-IP connection and request-rate limits. Replace its hostname and certificate paths before enabling it; do not expose port `28081` through a firewall or container port mapping.

## Future Work and Open Questions

- Consider a shared provider capability description for optional compatibility flags.
- Track compatibility changes to the ChatGPT Codex OAuth and Responses backend independently from the public API-key client.
