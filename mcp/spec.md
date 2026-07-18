## Goal

The `aqua/mcp/` module owns reusable Model Context Protocol client and server infrastructure without application identity, domain state, agent policy, or tool-provider policy.

## User Experience

- Applications can expose MCP tools to standard clients over the existing nonblocking `aqua/web` stack.
- MCP clients can initialize, discover tools, and call them through one Streamable HTTP endpoint.
- Applications inject their own server identity, native MCP tool metadata, authentication token, and listener configuration.
- A reusable native MCP client can drive protocol integration tests and later provide application-owned agents with MCP access without duplicating protocol code.

## Architecture Decisions

- `mcp.Server` owns JSON-RPC dispatch and the stateless Streamable HTTP request/response transport.
- Protocol dispatch should remain separable from HTTP transport so the same behavior can be tested directly and reused if another concrete transport is required.
- Tools implement the small `mcp.Tool` interface directly: MCP-native metadata plus an `execute(args)` method returning text and an optional error flag.
- Application adapters may implement multiple tool interfaces so one implementation can serve MCP and other agent protocols without duplicating behavior.
- Server identity is injected through `server_info`; the reusable module does not depend on `brand` or any application namespace.
- A future `mcp.Client` should use the same nonblocking web infrastructure, expose negotiated capabilities explicitly, and be suitable for both integration tests and application-owned agents.
- The initial transport does not open SSE streams or create sessions. `GET` and `DELETE` return HTTP 405 until server-initiated communication has a concrete consumer.

## Invariants

- The default listener address remains loopback-only.
- Requests with an `Origin` header are rejected to prevent browser-driven access to a local privileged server.
- The optional bearer token, request body limit, tool set, and timeouts are explicit server inputs.
- Tool calls execute in the coroutine handling the request; applications decide which scheduler thread owns that coroutine.
- Published input and output schemas are runtime contracts, not documentation only; protocol boundaries validate them before application code consumes values.
- Protocol errors use JSON-RPC errors, while successful tool dispatches report tool execution failures through MCP result content and `isError`.

## Protocol and Hardening Plan

1. Complete request validation: negotiated protocol-version handling, JSON-RPC batch behavior, method parameter validation, and schema validation for tool arguments.
2. Harden the HTTP listener: reject unauthenticated non-loopback binds, bound headers and concurrent clients, handle disconnects cleanly, and add rate limiting where remote exposure requires it.
3. Extend tool results with `structuredContent` and optional output schemas while retaining text content for client compatibility.
4. Implement a native `mcp.Client` with initialization, capability negotiation, tool discovery, calls, cancellation, timeouts, and deterministic shutdown.
5. Use the native client for end-to-end tests against `mcp.Server`, then make it available to application-owned agents when an integration has a concrete workflow.
6. Add sessions, SSE, progress, server requests, and tool-list change notifications only alongside consumers and lifecycle tests that require them.

## Future Work and Open Questions

- Determine whether the native client needs only Streamable HTTP or also stdio interoperability.
- Decide which JSON Schema subset can be validated with existing project dependencies before introducing another validator.
- Determine the concurrency and rate-limit defaults for loopback and authenticated remote listeners.
- Test interoperability with independent MCP clients and the official MCP Inspector in addition to native client integration tests.
