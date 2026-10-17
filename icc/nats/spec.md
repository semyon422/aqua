## Goal

Provide NATS-backed ICC delivery without sharing request-bound cosockets across OpenResty scopes.

## User Experience

Closing a connection releases its receiver and socket immediately; failed connections remain recoverable.

## Invariants

- The request or timer owning `RestyNats:start()` must call `close()` before returning, including error paths. Unsubscribing alone does not stop the receive loop; OpenResty waits for live user threads.
- `close()` cancels the receiving user thread before closing the socket, avoiding a cosocket busy-reading error. Call it from the spawning owner or from the receive callback itself; never kill the current thread. Repeated close is harmless and a later start creates a new connection.
- Request-owned connections must not enter the cosocket keepalive pool. The vendored client normalizes `keepalive=false` to true, so the wrapper explicitly disables pooling on the resulting client before use. Subscriber IDs and parser state are connection-specific.
- Receive-loop cleanup must not clear a newer replacement connection. Initial connect failures are cached until close; receive failures can reconnect on demand.
- Scope cleanup changes neither ICC payload encoding, reply subjects, broadcast subjects, nor no-return remote contracts.

## Verification

`RestyNats_test.lua` uses isolated module dependencies and coroutine-backed fake receivers to verify cancellation order, hard close rather than pooling, idempotence, recovery and callback-local close. `nats_test.lua` covers wire payloads and subject routing; downstream application tests cover context isolation and scope finalization.
