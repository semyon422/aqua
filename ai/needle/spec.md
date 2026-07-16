## Goal

Provide Soundsphere with a dependency-free, embeddable Needle inference runtime whose optimized execution lives in C and whose application API lives in LuaJIT.

## User Experience

- Needle-backed features work offline from the bundled quantized model.
- Inference runs outside the render thread and can be superseded when newer input arrives.
- Missing or incompatible native/model assets produce a recoverable unavailable state rather than preventing the game from loading.

## Architecture Decisions

- This directory is the development home for the runtime formerly maintained in `../needle/lua`; its original Git history and MIT license are retained.
- C owns model/tokenizer data, tensor execution, KV cache, and constrained greedy decoding. Lua owns FFI lifetime wrappers, tool schema constraints, and streaming callbacks.
- The runtime library is built by the target-aware `rizu/build` pipeline. The standalone Makefile remains available for runtime development and golden tests.
- Runtime model files embed their tokenizer. ABI 5 exposes `needle_tokenizer_from_context`, wrapped as `Context:createTokenizer()`, and the returned tokenizer owns its parsed data independently.
- The C runtime stays single-threaded. Applications must put each context on its own host worker and must not share contexts or caches concurrently.

## Invariants

- Lua validates the native ABI before any runtime call.
- Model and tokenizer handles are explicitly closeable and safe to close once.
- Constrained generation permits only tool names and argument keys present in the supplied schema.
- The q8 path retains scalar fallbacks for CPUs without AVX2/FMA.

## Development

- `make -C aqua/ai/needle test` builds the native library and runs dependency-light runtime tests.
- `make -C aqua/ai/needle test-real` runs checkpoint, quantization, and embedded-tokenizer validation using `NEEDLE_SOURCE` when the training repository is not at its default sibling path.
- The game loads the packaged library by the platform-neutral name `needle_runtime`; tests may override it with `NEEDLE_RUNTIME_LIB`.
