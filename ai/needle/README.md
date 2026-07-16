# Needle LuaJIT Runtime

This workspace contains the dependency-free runtime path for embedding Needle in LuaJIT applications.

The intended split is:

- C owns model loading, tokenization, inference, KV cache, and optimized kernels.
- Lua owns FFI bindings, app integration, tool schema preparation, and response handling.
- Python is used only for offline export and golden test generation.

## Build

```bash
cd lua
make
```

## Test

```bash
cd lua
make test
```

`make test` is the CI-friendly target: it builds the C library, creates tiny runtime/tokenizer fixtures, checks LuaJIT FFI loading, validates malformed model-file errors, and runs tiny golden tests.

For the full local validation against the real exported Needle checkpoint:

```bash
cd lua
make test-all
```

`make test-real` runs only the real-checkpoint golden comparison. It requires the checkpoint and tokenizer assets referenced by the Makefile.

## Export A Real Needle Checkpoint

```bash
cd ..
.venv/bin/python lua/scripts/export_needle_runtime.py \
  --checkpoint checkpoints/needle.pkl \
  --tokenizer needle/tokenizer/needle.model \
  --output lua/build/needle.bin
```

Then inspect it through LuaJIT:

```bash
cd lua
make
NEEDLE_RUNTIME_LIB="$PWD/build/libneedle_runtime.so" LUA_PATH="./?.lua;;" \
  luajit examples/run.lua build/needle.bin
```

## Example

```bash
cd lua
make example
```

Generation runs the float32 encoder-decoder path with greedy decoding, optional KV cache, and Lua-side constrained decoding for tool-call JSON. Experimental int8 projection kernels are available through the q8 export path while keeping float fallback weights.

For exact prefill/decode timing and reuse, create a C-owned encoder state:

```lua
local state = assert(ctx:encode_tokens_state(src_ids))
local ids = assert(ctx:generate_tokens_from_state(state, { 1 }, {
  max_new_tokens = 32,
  token_filter_raw = constraints:token_filter_raw(),
}))
state:close()
```

`make example-tool` and `make example-tool-q8` print query/tools, prefill time, decode time, q8 dispatch counters, and output. `make example-stream` streams text chunks from the q8 tool-call path and verifies they reconstruct the final text.

## Lua API

```lua
local needle = require("needle")

local ctx, err = needle.load("build/needle.bin")
if err then
  print(err.code, err.name, err.message)
end

if ctx and ctx:is_loaded() then
  local text, gen_err = ctx:generate("weather in Paris", tools_json, {
    tokenizer_path = "build/tokenizer.ndltok",
    max_new_tokens = 16,
    constrained = true,
    use_cache = true,
  })
  if not text then
    print(gen_err.name, gen_err.message)
  end
  ctx:close()
end
```

Streaming uses the same generation path and returns the final text after the callback has received chunks:

```lua
local text = assert(ctx:generate_stream("weather in Paris", tools_json, function(chunk)
  io.write(chunk)
  io.flush()
  return true
end, {
  tokenizer_path = "build/tokenizer.ndltok",
  constrained = true,
  use_cache = true,
}))
```

Errors are returned as tables:

```lua
{
  code = -8,
  name = "NOT_IMPLEMENTED",
  message = "generation is not implemented yet"
}
```

The public C ABI is versioned with `needle_abi_version()`. Lua validates it on load and fails fast on ABI mismatch. Current ABI: `5`.

Constrained token generation can restrict greedy argmax to valid token IDs:

```lua
local ids = assert(ctx:generate_tokens({ 10, 5, 20 }, { 1 }, {
  max_new_tokens = 2,
  allowed_token_ids_by_step = {
    { 8041 },
    { 4, 5 },
  },
}))
```

For dynamic constraints, pass `token_filter(step, tokens, logits, vocab_size)` and return a Lua array of allowed token IDs. Returning `nil` leaves that step unconstrained. For hot paths, `token_filter_raw(step, tokens, token_count, logits, vocab_size)` receives the C token pointer directly and avoids allocating a Lua token-history table for every decode step.

Tool-call constraints can also be built directly:

```lua
local tok = assert(needle.load_tokenizer("build/tokenizer.ndltok"))
local constraints = assert(needle.build_tool_call_constraints(tools_json, tok))
local filter = constraints:token_filter_raw()
```

The built-in tool-call constraint layer tracks compact JSON output, restricts `"name"` values to known tool names and argument keys to that tool's `parameters` keys, rejects duplicate argument keys, requires JSON Schema `required` keys before closing the `arguments` object, constrains string argument values with JSON Schema `enum`, and forces EOS after a complete top-level JSON array. `ctx:generate(..., { constrained = true })` uses the raw constraint path by default when no custom Lua table filter is provided. Non-enum argument values remain flexible.

## Tokenizer

Export the dependency-free tokenizer format:

```bash
cd lua
make build/tokenizer.ndltok
```

Use it from Lua:

```lua
local tok = assert(needle.load_tokenizer("build/tokenizer.ndltok"))
local ids = assert(tok:encode("weather in Paris"))
local text = assert(tok:decode(ids))
tok:close()
```

## Tensor Inspection

```lua
local ctx = assert(needle.load("build/needle.bin"))
local idx = assert(ctx:find_tensor("embedding/embedding"))
local tensor = assert(ctx:tensor(idx))
print(tensor.dtype_name, table.concat(tensor.shape, "x"))

local embedding = assert(ctx:embedding(4))
print(#embedding)
ctx:close()
```

## KV Cache

The runtime exposes an opaque KV cache handle for decoder self-attention work. Cached decoding is still being wired in, but allocation, reset, bounds checks, and Lua ownership are available:

```lua
local cache = assert(ctx:create_kv_cache(128))
print(cache:info().bytes)
local attn = assert(ctx:decoder_self_attention_cached_step(cache, 0, decoder_row))
local block = assert(ctx:decoder_block_cached_step(cache, 0, decoder_row, encoder_out, enc_len))
local decoded = assert(ctx:decode_token_cached_step(cache, token_id, encoder_out, enc_len))
assert(cache:set_token_count(0))
assert(cache:reset())
cache:close()
```

For normal generation, pass `use_cache = true` to `generate_tokens` or `generate`.

Benchmark cached vs uncached greedy generation:

```bash
cd lua
BENCH_ITERS=3 BENCH_MAX_NEW=8 make bench-kv
```

Profile encoder/generation timing plus aligned allocation churn:

```bash
cd lua
BENCH_ITERS=5 BENCH_MAX_NEW=8 make bench-profile
```

## Production Notes

The runtime returns structured errors for malformed model files, including invalid magic, truncated headers, unsupported format versions, invalid tensor dtypes, and trailing bytes. These cases are covered by `tests/test_loader_errors.lua`.

CPU-specific acceleration is optional. On x86 builds with GCC/Clang, AVX2/FMA kernels are selected at runtime only when the CPU reports support; otherwise scalar fallback code is used. This includes float dot/projection helpers and q8 projection kernels. The shared library remains dependency-free by default.

The v1 runtime is intentionally single-threaded. It does not create worker threads or own a global thread pool; applications that need parallelism should run independent model/context handles in their own LuaJIT workers or host threads. Do not share one context or KV cache across concurrent calls without external synchronization.

Quantization starts with int8 dense/projection kernels plus int8 tied-output embedding logits, while keeping float fallback tensors where the runtime still needs them. Dense kernels use symmetric per-output-channel int8 weights plus float32 scale tensors; tied output projection uses symmetric per-token-row int8 embedding weights plus float32 row scales. Int4 and AVX-VNNI-specific kernels are deferred until the portable int8 path is correct and benchmarked.

Export an experimental int8 container with fallback float weights still present:

```bash
cd lua
make export-q8
```

Export a smaller int8 container that strips quantized float kernel payloads:

```bash
cd lua
make export-q8-stripped
```

`make export-q8-stripped` replaces float payloads for quantized dense kernels with one-byte placeholders while retaining q8 weights/scales. The runtime dispatches those kernels through q8 and also uses `embedding/embedding.q8` for tied output logits when present. The original embedding stays in the file for token lookup.

Compare the experimental q8 runtime path against float generation:

```bash
cd lua
BENCH_ITERS=3 BENCH_MAX_NEW=4 make bench-q8
BENCH_ITERS=3 BENCH_MAX_NEW=4 make bench-q8-stripped
make bench-q8-quality
```

`tests/test_memory_stats.lua` exercises model load, encode/decode, uncached generation, cached generation, and explicit KV cache lifecycle, then verifies that runtime aligned allocations return to their baseline after handles are closed. This guards the runtime scratch/KV/tensor-cache allocator; external tools such as ASan or Valgrind can still be layered on top for full process leak checks.

`needle.memory_stats()` also reports dense and output projection dispatch counters:
`dense_q8_projection_count`, `dense_float_projection_count`, `dense_q8_fallback_count`, `output_q8_projection_count`, `output_float_projection_count`, and `output_q8_fallback_count`.
Use these in production smoke checks to confirm an int8 model is actually running q8 kernels and q8 output logits instead of silently falling back to float.

## Packaging

For a LuaJIT application, ship these runtime files together:

```text
needle.lua
build/libneedle_runtime.so
build/needle.bin
build/tokenizer.ndltok
```

Linux builds currently produce `libneedle_runtime.so`:

```bash
cd lua
make clean
make
```

Load it by setting `NEEDLE_RUNTIME_LIB` to an absolute path, or place the library at `./build/libneedle_runtime.so` relative to the process working directory. Keep `LUA_PATH` configured so `require("needle")` finds `needle.lua`.

On macOS, build a dynamic library with the platform compiler and use a `.dylib` output name, for example:

```bash
cd lua
make clean
make LIB=build/libneedle_runtime.dylib LDFLAGS="-dynamiclib -lm"
```

Then point `NEEDLE_RUNTIME_LIB` at the `.dylib`. The runtime itself does not depend on Python, JAX, SentencePiece, or libc++ at inference time; Python is only needed to export `.bin`/`.ndltok` assets and generate golden fixtures.

## Runtime Override

By default `needle.lua` loads `./build/libneedle_runtime.so`. Override it with:

```bash
NEEDLE_RUNTIME_LIB=/absolute/path/to/libneedle_runtime.so luajit examples/run.lua
```
