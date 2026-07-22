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
- A Responses result ending with `incomplete_details.reason = max_output_tokens` remains a successful partial Chat Completion with `finish_reason = length`, including when the limit is reached before visible text. Unknown incomplete reasons remain upstream errors rather than being reported as successful completion.
- A completed refusal is preserved as assistant text with `finish_reason = stop`. Local or upstream cancellation remains a transport error because Chat Completions has no cancellation finish reason.
- Deprecated `functions` and `function_call` requests are normalized to one modern function tool and tool choice path. Legacy assistant `function_call` and role `function` history receives a private synthetic call ID so the Responses backend can correlate the call and result.
- Legacy function mode disables parallel calls because its response schema can represent only one call. JSON and SSE responses use the legacy `message.function_call`, `delta.function_call`, and `finish_reason = function_call` shapes; mixing legacy and modern tool controls is rejected as ambiguous.
- `[DONE]` terminates a successful stream. A closed stream without `[DONE]` is an error unless it was explicitly canceled.
- Proxy model names are allowlisted. Proxy logs contain only the configured user name, remote address, method, path, status, and duration; prompts, responses, client tokens, and subscription credentials are never logged.
- Every upstream request has a unique `x-client-request-id`. Provider failures return the bounded `x-request-id` when available, or that client request ID as a troubleshooting fallback.
- Proxy request bodies require exactly one `Content-Length`; transfer encoding and duplicate lengths are rejected before the body is buffered. Header, request-body, upstream-response, global connection, per-user concurrency, and per-user request-rate limits are enforced independently.
- When a streaming request sets `stream_options.include_usage`, the proxy maps Responses token counts to Chat Completions usage fields and emits the final usage-only chunk with an empty `choices` array before `[DONE]`. Non-streaming completions include the same usage object when upstream reports it.
- A Chat Completions request may set `reasoning_effort` to override the proxy config for that request. Omitting it uses the configured default; invalid values fail before an upstream request is made.
- The proxy translates `prompt_cache_key`, `tool_choice`, `parallel_tool_calls`, and `response_format` to their Responses equivalents. A client-provided cache key is forwarded unchanged; when absent, the upstream field is omitted so automatic prefix caching remains available. Forced function choices are flattened to a Responses function selector, while Chat Completions JSON-schema formats become `text.format` objects. Parallel tool calls default to enabled like Chat Completions; clients can set the field to `false` to restrict a response to at most one function call.
- `prompt_cache_options` accepts only `implicit` or `explicit` mode and the currently documented `30m` TTL. Explicit breakpoints are retained only on Responses-compatible input text, image, and file blocks; unsupported placements fail locally. These fields are forwarded rather than silently downgraded to implicit caching, so the current subscription backend reports its lack of support accurately.
- `response.reasoning_summary_text.delta` events are exposed to Chat Completions clients as `delta.reasoning_content`; non-streaming responses include the assembled reasoning summary on the assistant message when one is available. Encrypted provider reasoning remains private and cannot be reconstructed from client-supplied summaries.
- `max_completion_tokens` and legacy `max_tokens` are validated and accepted for Chat Completions compatibility, but the ChatGPT Codex subscription backend rejects the Responses `max_output_tokens` field. The proxy therefore relies on the selected model's output cap instead of forwarding a client-selected lower cap.
- The subscription backend rejects `temperature` and `top_p` even when reasoning effort is `none`. Their documented defaults of `1`, `n = 1`, zero penalties, `logprobs = false`, and empty stop or logit-bias values are accepted as no-ops. Non-default sampling, multiple choices, stop sequences, seed, log probabilities, penalties, and logit bias fail explicitly instead of being silently ignored.
- The proxy accepts `developer`, `system`, `user`, `assistant`, and `tool` messages plus function tools. Chat Completions user parts map to subscription Responses parts: `text` to `input_text`, `image_url` to `input_image`, `input_audio` remains `input_audio`, and `file` maps to `input_file`. Assistant `text` and `refusal` history is normalized to text. Unsupported or malformed content fails instead of being silently discarded.
- The public Responses request schema currently documents text, image, and file message content but not `input_audio`. Audio is forwarded as a compatibility extension and can still be rejected by the ChatGPT subscription backend or selected model.

## Compatibility Progress

The proxy targets agent clients that speak OpenAI Chat Completions while using the ChatGPT Codex Responses backend upstream.

| Feature | Status | Notes |
| --- | --- | --- |
| Chat Completions text and SSE | Implemented | Includes strict terminal chunks and optional streaming usage. |
| Function tools and tool choice | Implemented | Includes forced functions and parallel calls. |
| Incremental tool-call streaming | Implemented | Call identity and argument fragments are relayed as soon as upstream emits them. |
| Reasoning effort and summaries | Implemented | Effort is request-controlled; summaries use `reasoning_content`. |
| Response verbosity | Implemented | `low`, `medium`, and `high` map to Responses `text.verbosity`. |
| Structured output | Implemented | Supports text, JSON object, and JSON Schema formats. |
| Multimodal input | Implemented | Text, images, files, and compatibility audio input are translated. |
| Prompt caching | Partial; upstream blocked | Cache keys and automatic caching work. Explicit mode, `30m` TTL, and supported content breakpoints are validated and translated, but the current ChatGPT subscription backend rejects these newer fields. |
| Direct `/v1/responses` | Planned | Avoids lossy translation for Responses-native clients. |
| Upstream error fidelity | Implemented | Returns bounded provider status, code, message, and request ID without logging prompts or credentials. |
| Optional generation parameters | Implemented with backend limits | Harmless defaults are accepted. Non-default sampling, stop, logprob, seed, penalty, logit-bias, and multi-choice controls return explicit unsupported-parameter errors. |
| Completion state mapping | Implemented | Preserves normal, tool-call, output-limit, and content-filter terminal reasons. Completed refusals are normal assistant output; cancellation and unknown incomplete states remain errors. |
| Legacy function aliases | Implemented | Translates legacy definitions, choices, conversation history, non-streaming responses, and streaming deltas while enforcing single-call semantics. |

## Standalone Proxy

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

An alternate config path can be passed as the first argument when serving or after the login command, for example `proxy.lua login userdata/other_proxy.lua`. The default listener is loopback-only at `http://127.0.0.1:28081/v1`. The entrypoint refuses placeholder or shorter-than-32-character client tokens. The service loads subscription OAuth credentials from ignored `userdata/ai_auth.lua`, loads SOCKS5 routing from ignored `userdata/network.lua`, verifies upstream TLS against the repository CA bundle, and atomically persists login and refreshed credentials. Serving without an access or refresh credential fails with a command showing how to log in.

For public access, keep the Lua server bound to `127.0.0.1` and terminate HTTPS at Nginx using `nginx_proxy.example.conf` as a starting point. The example preserves Authorization, disables response buffering for SSE, buffers and bounds request bodies, and applies public-IP connection and request-rate limits. Replace its hostname and certificate paths before enabling it; do not expose port `28081` through a firewall or container port mapping.

## Future Work and Open Questions

- Consider a shared provider capability description for optional compatibility flags.
- Track compatibility changes to the ChatGPT Codex OAuth and Responses backend independently from the public API-key client.
