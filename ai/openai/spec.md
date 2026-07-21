## Goal

Provide reusable OpenAI-compatible Chat Completions and ChatGPT subscription clients plus an agent loop, without depending on application-specific models, tools, configuration, or UI.

## User Experience

- Applications can send a conversation to an OpenAI-compatible provider and receive either an assistant response or function-tool calls.
- Applications can register local tools and let the agent repeat the request/tool/result cycle until it produces a final answer.
- Applications can opt into a browser-based ChatGPT subscription login with a PKCE loopback callback and use the Codex Responses compatibility backend.
- Transport, provider, JSON, and tool failures are returned as useful errors instead of escaping into the application loop.

## Architecture Decisions

- `Client` owns only the `/chat/completions` protocol: request encoding, authentication headers, response decoding, and response-shape validation.
- `SubscriptionAuth` owns the reusable PKCE authorization, callback-state validation, token refresh, and credential mutation. HTTP requests, scheduling, browser opening, credential persistence, and time are injected.
- `SubscriptionClient` translates common agent messages and function tools to the Responses input protocol. It assembles output from typed SSE events and retains provider-owned output items, including encrypted reasoning, across stateless tool rounds.
- The HTTP request function is injected. The common layer does not create a scheduler or depend on `rizu.net.NetworkService`.
- `Agent` owns the reusable tool-calling loop. Tools provide an OpenAI function schema and a Lua handler; application-specific tool implementations remain outside `aqua`.
- `Client:completeStream()` implements Chat Completions server-sent events without changing the existing complete-response API. It emits text deltas while assembling one protocol-valid assistant message, including fragmented tool call IDs, names, and JSON arguments.
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

## Future Work and Open Questions

- Consider a shared provider capability description for optional compatibility flags.
- Track compatibility changes to the ChatGPT Codex OAuth and Responses backend independently from the public API-key client.
