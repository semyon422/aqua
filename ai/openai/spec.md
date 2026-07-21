## Goal

Provide a small reusable client and agent loop for OpenAI-compatible Chat Completions providers without depending on application-specific models, tools, configuration, or UI.

## User Experience

- Applications can send a conversation to an OpenAI-compatible provider and receive either an assistant response or function-tool calls.
- Applications can register local tools and let the agent repeat the request/tool/result cycle until it produces a final answer.
- Transport, provider, JSON, and tool failures are returned as useful errors instead of escaping into the application loop.

## Architecture Decisions

- `Client` owns only the `/chat/completions` protocol: request encoding, authentication headers, response decoding, and response-shape validation.
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
- `[DONE]` terminates a successful stream. A closed stream without `[DONE]` is an error unless it was explicitly canceled.

## Future Work and Open Questions

- Consider a shared provider capability description for optional compatibility flags.
- Add Responses API support only as a separate protocol surface rather than changing Chat Completions message semantics.
