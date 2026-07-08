## Goal

The `aqua/web/` module owns reusable HTTP, websocket, socket, OpenResty, and LuaSocket infrastructure. Its client-side cosocket work should provide OpenResty-like nonblocking socket behavior for LuaSocket environments, especially the LÖVE main thread, without adding project-specific policy to `aqua`.

## User Experience

- Callers should be able to run websocket and HTTP-style network flows from the main thread without blocking frame updates while waiting for socket readiness.
- Existing `web.http`, `web.ws`, and `web.socket` parsers should remain reusable across OpenResty, blocking LuaSocket, and nonblocking LuaSocket transports.
- Network failures, timeouts, and reconnect loops should be surfaced as normal socket errors rather than freezing the caller.

## Architecture Decisions

- Implement nonblocking client networking in `aqua/web`, not in `rizu/online`, so the transport remains reusable.
- Treat `require("coext").export()` as part of the runtime coroutine model. Cosocket operations may rely on `coext` to ensure socket waits yield to their owning coroutine rather than an unrelated caller coroutine.
- Keep websocket framing and HTTP parsing transport-agnostic. Prefer adapting `web.ITcpSocket` / `web.IExtendedSocket` implementations over changing `Websocket`, `WebsocketClient`, `Request`, or `Response`.
- Use the existing `ExtendedSocket.cosocket` and `TcpUpdater` behavior as prior art, but extend the design for client-side `connect`, SSL handshakes, timers, cancellation, and multiple wait states.
- Use Copas as an implementation reference for nonblocking LuaSocket edge cases:
  - async `connect` waits on write readiness and retries until connected or failed;
  - LuaSec `dohandshake` may alternate between `wantread` and `wantwrite`;
  - partial `send` must continue from the last written byte;
  - socket timeouts should be tracked by coroutine operation, not by blocking the OS socket.
- DNS resolution is expected to block in LuaSocket. Do not hide this inside the cosocket scheduler; resolve hosts through a worker thread or another explicit resolver layer when main-thread DNS becomes necessary.

## Invariants

- Cosocket transport methods must not block the main thread on socket readiness.
- Cosocket socket waits must yield only through the coroutine that owns the network operation.
- Closed or canceled sockets must be removed from scheduler read/write queues before the next `select`.
- Existing blocking socket implementations must keep their current contracts.
- `aqua/web` must not depend on `rizu`, `sea`, or other application-specific modules.

## Implementation Plan

1. Define a small scheduler API for LuaSocket cosockets.
   - Track read waiters, write waiters, and timers.
   - Resume waiters from `update(timeout)` after `socket.select`.
   - Provide cleanup for close, cancel, and timeout paths.
   - Initial implementation: `web.luasocket.CosocketScheduler`.

2. Add a LuaSocket cosocket adapter.
   - Expose a `web.ITcpSocket`-compatible object for nonblocking TCP.
   - Implement async `connect`, `receive`, `send`, `selectreceive`, and `selectsend`.
   - Preserve partial read/write behavior expected by existing socket tests.
   - Initial implementation: `web.luasocket.CosocketTcpSocket` with fake-socket tests.

3. Add SSL support.
   - Keep `sslwrap` and `sni` compatible with `LsTcpSocket`.
   - Implement nonblocking `sslhandshake` with `wantread` / `wantwrite` handling.
   - Copy timeout and cleanup behavior across the raw-to-SSL socket replacement.
   - Initial fake-socket verification covers `wantread`, `wantwrite`, timeout, and fatal error paths.

4. Reuse existing HTTP and websocket code.
   - Verify `WebsocketClient:connect`, `Websocket:handshake`, `Websocket:step`, `Request`, and `Response` work over the cosocket adapter.
   - Avoid changing parser behavior unless tests reveal a transport contract bug.
   - Initial verification: local `ws://` smoke test over `CosocketTcpSocket`.

5. Add focused tests.
   - Scheduler tests for read wait, write wait, timers, timeout, close, and cancel.
   - Plain TCP client/server integration tests for connect, send, and receive.
   - Websocket integration tests over the new transport.
   - SSL handshake tests when the local environment can provide stable certificates and LuaSec support.

6. Integrate downstream after `aqua/web` is stable.
   - Add a main-thread transport option to `rizu.online.SphereWebsocket`.
   - Make `SeaClient.threaded = false` use the cosocket transport and scheduler updates.
   - Add a separate DNS resolver thread if hostname resolution blocks frame updates in practice.

## Future Work and Open Questions

- Decide whether the scheduler should be per-client object, shared singleton, or explicitly injected into each cosocket.
- Decide whether `delay` should remain separate from web timers or whether a small timer primitive belongs in the cosocket scheduler.
- Decide how to expose DNS resolution without coupling `aqua/web` to LÖVE thread APIs.
- Audit whether ICC `TaskHandler` callbacks need scheduler-specific helpers once websocket sends can yield on write readiness.

## Current Progress

- Added the initial `web.luasocket.CosocketScheduler` with injectable `select` and clock dependencies.
- Covered scheduler behavior with focused tests for read/write readiness, timers, close, cancel, multiple waiters, re-waiting after resume, and select errors.
- Added the initial `web.luasocket.CosocketTcpSocket` for nonblocking plain TCP operations over the scheduler.
- Covered the TCP adapter with fake-socket tests for async connect, operation timeout, partial receive, partial send, `wantread` during send, select polling, and close wakeup.
- Covered fake SSL handshake behavior for `wantread`, `wantwrite`, timeout, and fatal error paths.
- Added a real localhost TCP integration test that verifies nonblocking connect, client-to-server send, and server-to-client receive.
- Added a real localhost websocket smoke test that verifies `WebsocketClient`, HTTP handshake, websocket handshake, and text frame round-trip over `CosocketTcpSocket`.
- Verified the scheduler manually with global `coext.export()` enabled.
