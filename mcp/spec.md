## Goal

The `aqua/mcp/` module owns reusable Model Context Protocol handling without application identity, game state, or tool-provider policy.

## User Experience

- Applications can expose MCP tools over the existing nonblocking `aqua/web` stack.
- MCP clients can initialize, discover tools, and call them through one Streamable HTTP endpoint.
- Applications inject their own server identity, native MCP tool metadata, authentication token, and listener configuration.

## Architecture Decisions

- `mcp.Server` owns JSON-RPC dispatch and the stateless Streamable HTTP request/response transport.
- Tools implement the small `mcp.Tool` interface directly: MCP-native metadata plus an `execute(args)` method returning text and an optional error flag.
- Application adapters may implement multiple tool interfaces. The running game reuses `rizu.ai.LuaEvalTool` for both OpenAI function calling and MCP.
- Server identity is injected through `server_info`; the reusable module does not depend on `brand` or any application namespace.
- The initial transport does not open SSE streams or create sessions. `GET` and `DELETE` return HTTP 405.

## Invariants

- The default listener address remains loopback-only.
- Requests with an `Origin` header are rejected to prevent browser-driven access to a local privileged server.
- The optional bearer token, request body limit, and tool set are explicit server inputs.
- Tool calls execute in the coroutine handling the request; applications decide which scheduler thread owns that coroutine.

## Future Work and Open Questions

- Add SSE only when an application needs server-initiated requests or notifications.
- Consider separating protocol dispatch from HTTP transport if another concrete transport is required.
