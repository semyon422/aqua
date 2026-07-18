## Goal

The `json` module provides a dependency-free JSON encoder and decoder for LuaJIT applications using `aqua`, with explicit representations for JSON objects, arrays, and null.

## User Experience

- Callers use `json.encode`, `json.decode`, and `json.decode_safe` without depending on a native JSON module.
- `json.object()` and `json.array()` preserve container identity, including for empty containers.
- Decoded objects and arrays retain their JSON container type when re-encoded.
- `json.null` preserves null values inside arrays and objects.

## Architecture Decisions

- The implementation lives at `aqua/json.lua`; the legacy `web.json` module remains a compatibility alias.
- Untagged non-empty tables infer their shape from key type. Untagged empty tables continue to encode as arrays for compatibility with the previous project JSON implementation.
- Object keys are emitted in sorted order for deterministic output.
- Numbers use 17 significant digits to preserve Lua number round trips.
- The decoder implements the JSON number grammar and Unicode surrogate-pair handling directly rather than accepting Lua-specific syntax.

## Invariants

- Objects contain only string keys.
- Arrays contain only contiguous positive integer keys.
- NaN, infinities, unsupported Lua values, sparse arrays, mixed-key tables, circular references, and nesting beyond 128 levels are rejected.
- Unescaped control characters, malformed numbers, invalid escapes, unpaired Unicode surrogates, and trailing input are rejected during decoding.
- `decode_safe` returns `nil, error` instead of raising for malformed input.

## Future Work and Open Questions

- Add streaming encode/decode only when a caller cannot reasonably buffer a complete document.
- Consider configurable duplicate-key rejection if an integration requires it; decoding currently keeps the last value.
