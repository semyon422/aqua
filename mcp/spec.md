## Goal

The `aqua/mcp/` module owns reusable Model Context Protocol client and server infrastructure without application identity, domain state, agent policy, or tool-provider policy.

## User Experience

- Applications can expose MCP tools to standard clients over the existing nonblocking `aqua/web` stack.
- MCP clients can initialize, discover tools, and call them through one Streamable HTTP endpoint.
- Applications inject their own server identity, native MCP tool metadata, authentication token, and listener configuration.
- A reusable native MCP client can drive protocol integration tests and later provide application-owned agents with MCP access without duplicating protocol code.

## Architecture Decisions

- `mcp.Protocol` is the shared source of truth for the latest and supported protocol versions. Servers negotiate from it, and clients reject initialize results outside it.
- `mcp.Server` owns JSON-RPC dispatch and the stateless Streamable HTTP request/response transport.
- Protocol dispatch should remain separable from HTTP transport so the same behavior can be tested directly and reused if another concrete transport is required.
- Tools implement the small `mcp.Tool` interface directly: MCP-native metadata plus an `execute(args)` method returning either `mcp.ToolResult` or the legacy text/error/structured-content tuple.
- `mcp.ToolResult` supports text, image, audio, embedded-resource, and resource-link content blocks. The server validates block shape and base64 payloads before returning them to clients.
- Tools may publish an output schema. The server advertises it, requires structured content from that tool, and validates the content before returning it to clients.
- Application adapters may implement multiple tool interfaces so one implementation can serve MCP and other agent protocols without duplicating behavior.
- Server identity is injected through `server_info`; the reusable module does not depend on `brand` or any application namespace.
- `mcp.Client` uses the same nonblocking web infrastructure and is suitable for integration tests and application-owned agents. It owns initialization, capability negotiation, bearer and session headers, JSON-RPC request IDs, tool discovery and calls, pings, notifications, local stream cancellation, protocol cancellation, session termination, timeouts, and deterministic closure.
- Client failures use `mcp.ClientError`, distinguishing transport, HTTP, protocol, and JSON-RPC errors while preserving HTTP status, headers, body, and structured error data when available.
- Streamable HTTP remains stateless unless the application supplies `session_id_generator`. Stateful servers issue `Mcp-Session-Id`, scope active requests by session, accept session termination through `DELETE`, and route `notifications/cancelled` to `mcp.RequestContext`.
- Applications may supply `mcp.SessionStore` to restore valid session IDs after process restart. Only the registry is restored; active requests and cancellation contexts remain process-local.
- The transport does not open SSE streams. `GET` returns HTTP 405 until server-initiated communication has a concrete consumer.

## Invariants

- The default listener address remains loopback-only, and a non-loopback listener cannot start without a non-empty bearer token.
- Requests with an `Origin` header are rejected to prevent browser-driven access to a local privileged server. Bearer credentials are accepted only from one Authorization header.
- The optional bearer token, request body limit, tool set, client limit, rate limit, and timeouts are explicit server inputs. MCP defaults to at most 16 active clients.
- Non-loopback listeners default to a per-IP fixed-window limit of 120 endpoint requests per minute. `rate_limit` and `rate_limit_window` configure it; an explicit `rate_limit = 0` disables it.
- Stateless HTTP requests accept supported `MCP-Protocol-Version` values and reject explicitly unsupported versions. JSON-RPC batches produce only requested responses and cannot contain initialization.
- Tool calls execute in the coroutine handling the request; applications decide which scheduler thread owns that coroutine.
- Published input and output schemas are runtime contracts, not documentation only; protocol boundaries validate them before application code consumes values.
- `mcp.JsonSchema` enforces the tool-schema subset currently used by the project: primitive/object/array types, required and additional properties, nested property/item schemas, enums, numeric bounds, and array-size bounds. Expanding that subset requires focused validator tests.
- Protocol errors use JSON-RPC errors, while successful tool dispatches report tool execution failures through MCP result content and `isError`.
- JSON-RPC request IDs are client-scoped, not globally unique. Cancellation is routed only inside an explicit session; stateless cancellation notifications do not target active calls.
- Session shutdown preserves IDs owned by `mcp.SessionStore`, while explicit `DELETE` removes them. Restored sessions always begin with an empty active-request set.
- Tools receive `mcp.RequestContext`, can register cancellation handlers, and must cooperatively stop long-running work after cancellation. Session shutdown cancels every active context.

## Protocol and Hardening Plan

1. Make the native client available to application-owned agents when an integration has a concrete workflow.
2. Add SSE, progress, server requests, and tool-list change notifications only alongside consumers and lifecycle tests that require them.

## Future Work and Open Questions

- Determine whether the native client needs only Streamable HTTP or also stdio interoperability.
- Decide which JSON Schema subset can be validated with existing project dependencies before introducing another validator.
- Determine the concurrency and rate-limit defaults for loopback and authenticated remote listeners.
- Automate interoperability checks with independent MCP clients and the official MCP Inspector in addition to native client integration tests. The stateless server is manually verified with the official JavaScript SDK.
