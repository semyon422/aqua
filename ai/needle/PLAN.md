# Needle LuaJIT Runtime Plan

Goal: build a production-ready Needle inference runtime for LuaJIT projects, with performance-critical model execution in C and integration/control code in Lua.

## Principles

- Keep the C runtime dependency-free by default.
- Use LuaJIT FFI as the stable integration layer.
- Do not load Python pickle files from C. Export checkpoints to a simple runtime format first.
- Make every stage testable against the existing Python/JAX implementation.
- Start with correctness in float32, then add cache, quantization, SIMD, and packaging.

## Ownership Split

### C

- Runtime model loader.
- Tensor storage and memory ownership.
- Tokenizer implementation.
- Forward pass.
- Generation loop.
- KV cache.
- Constrained decoding primitives.
- SIMD kernels.
- Public C ABI for LuaJIT FFI.

### Lua

- FFI bindings.
- User-facing module API.
- Tool schema preparation.
- Response parsing and validation.
- Runtime configuration.
- Tests and examples that match target project usage.

### Python

- One-way export from Needle checkpoint/tokenizer files to runtime assets.
- Golden-output generation for C/runtime tests.
- Optional diagnostics during development only.

## Target Artifact Layout

```text
lua/
  PLAN.md
  README.md
  Makefile
  src/
    needle_runtime.c
    needle_runtime.h
    needle_model.c
    needle_model.h
    needle_tokenizer.c
    needle_tokenizer.h
    needle_kernels.c
    needle_kernels.h
  scripts/
    export_needle_runtime.py
    golden.py
  needle.lua
  examples/
    run.lua
  tests/
    test_ffi.lua
    test_loader.lua
    test_tokenizer.lua
```

## Milestones

### 0. Workspace Bootstrap

- [x] Create `lua/` workspace.
- [x] Add progress plan.
- [x] Add minimal C shared library build.
- [x] Add LuaJIT FFI smoke test.
- [x] Add README with build/run commands.

Done when: `make test` builds a shared library and LuaJIT calls a C function through FFI.

### 1. Runtime Asset Format

- [x] Define `needle.bin` model format.
- [x] Define `tokenizer.bin` format or embedded tokenizer section.
- [x] Write Python exporter from `checkpoints/needle.pkl`.
- [x] Export config, tensor names, shapes, dtypes, and raw bytes.
- [x] Add checksum/version metadata.
- [x] Add C loader that validates headers and tensor table.

Done when: C loader prints the same config and tensor inventory as Python.

### 2. C ABI and Lua API

- [x] Define stable C API:
  - `needle_load`
  - `needle_free`
  - `needle_generate`
  - `needle_last_error`
  - optional streaming callback API
- [x] Implement LuaJIT FFI declarations.
- [x] Wrap C handles safely in Lua.
- [x] Add simple Lua example.

Done when: Lua can load runtime assets and receive structured errors.

### 3. Tokenizer

- [x] Inspect Needle tokenizer requirements.
- [x] Export tokenizer data to dependency-free runtime format.
- [x] Implement encode in C.
- [x] Implement decode in C.
- [x] Add Python-vs-C tokenization tests.

Done when: representative queries/tools round-trip and token IDs match Python.

### 4. Float32 Model Correctness

- [x] Port config struct.
- [x] Implement tensor lookup and shape checks.
- [x] Implement embeddings.
- [x] Implement RMSNorm/ZCRMSNorm.
- [x] Implement RoPE.
- [x] Implement attention.
- [x] Implement gated residuals.
- [x] Implement output projection.
- [x] Compare layer outputs against Python golden data.
- [x] Compare final logits against Python.

Done when: C logits match Python within agreed tolerance for fixed inputs.

Current status: tensor payloads are loaded into C memory, Lua can inspect tensor metadata, and `embedding/embedding` lookup converts f32/f16 rows to float32. Config parsing, float32 ZCRMSNorm, float32 RoPE, matmul, masked softmax, and single-head attention kernels are implemented and tested. A tensor-backed encoder self-attention primitive performs Q/K/V projections, Q/K norm, RoPE, GQA repeat, attention, and out projection for one encoder layer. `needle_encoder_block_f32` adds pre-norm plus sigmoid-gated residual. `needle_encode_tokens_f32` implements embedding scale, all encoder layers, and final norm. `needle_decoder_self_attention_f32` implements causal decoder self-attention. `needle_decoder_cross_attention_f32` implements decoder-to-encoder cross-attention. `needle_decoder_block_f32` adds decoder pre-norms plus self/cross gated residuals for one decoder layer. `needle_decode_tokens_f32` implements embedding scale, all decoder layers, and final decoder norm. `needle_forward_logits_f32` implements full encoder-decoder forward plus tied logits. Tiny and real-checkpoint golden tests pass (`make test-real`, current max diff around 0.001 for encoder attention, 0.0014 for decoder self-attention, 0.0044 for decoder cross-attention, 0.0016 for decoder block, 0.0007 for encoder block, 0.026 for standalone logits, 0.000004 for full encoder, 0.000001 for full decoder, and 0.00002 for full forward logits). Mask plumbing for padding/packing and generation are still pending. Real checkpoint config and embedding values match Python for sampled rows.

### 5. Generation

- [x] Implement greedy decode.
- [x] Implement EOS stopping.
- [x] Implement tool-call stopping.
- [x] Implement max length limits.
- [x] Add Lua `generate(query, tools, opts)` API.
- [x] Add golden generation tests.

Done when: Lua example produces the same tool-call output as Python for fixtures.

Current status: `needle_generate_tokens_greedy` and `ctx:generate_tokens(src_ids, prompt_ids, opts)` generate token IDs using full encoder-decoder forward and argmax. EOS is handled inside the C generation loop and stripped from decoded Lua output. `ctx:generate(query, tools, opts)` now uses a tokenizer, compacts tools JSON, assembles `query + <tools> + tools`, starts from `[EOS]` by default, strips the prompt/EOS plus leading `<tool_call>` from decoded output, and respects `max_new_tokens`. `needle_generate_tokens_greedy_filtered` adds a C token-filter callback, exposed from Lua as `allowed_token_ids_by_step`, `token_filter`, and `token_filter_raw`, so constrained decoding can restrict argmax to valid token IDs. The raw callback receives the C token pointer directly and avoids allocating a Lua token-history table per decode step. `needle_generate_tokens_greedy_cached_from_state_stream_filtered`, `ctx:generate_tokens_from_state(..., { on_token = fn })`, and `ctx:generate_stream(..., on_text, opts)` stream selected tokens/chunks from the cached C-owned encoder-state path while still returning the final text. `needle_encoder_state` plus `ctx:encode_tokens_state(src_ids)` and `ctx:generate_tokens_from_state(state, prompt_ids, opts)` provide a C-owned prefilled encoder state for exact prefill/decode timing and decode without re-running the encoder or copying encoder output through Lua tables. `ctx:generate(..., { constrained = true })` builds a Lua tool-call constraint state machine over tokenizer token text, uses the raw filter path by default, and restricts tool names, argument keys, duplicate argument keys, JSON Schema `required` object keys, and string `enum` argument values from JSON Schema-style `parameters.properties`. Once a complete top-level tool-call JSON array is emitted, the constraint layer forces EOS so generation stops structurally. Tiny deterministic generation, string-level orchestration tests, constrained-generation tests, enum-value tests, required-key tests, duplicate-key tests, malformed-output regressions, tokenizer/state-machine tests, streaming tests, from-encoder/from-state generation tests, and real-checkpoint generation ID comparison pass.

### 6. KV Cache

- [x] Define cache layout.
- [x] Add decoder self-attention KV cache.
- [x] Add full multi-layer cached decoder step.
- [x] Add reset/reuse lifecycle.
- [x] Add memory bounds checks.
- [x] Wire cache into greedy generation.
- [x] Benchmark with and without cache.

Done when: cached generation matches uncached generation and improves decode speed.

Current status: `needle_kv_cache` is an opaque C handle with contiguous float32 K/V buffers sized as `decoder_layers * max_tokens * num_kv_heads * head_dim` for each of K and V. Lua exposes `ctx:create_kv_cache(max_tokens)`, `cache:info()`, `cache:set_token_count(n)`, `cache:reset()`, and `cache:close()`. `needle_decoder_self_attention_cached_step_f32` and `ctx:decoder_self_attention_cached_step(cache, layer, row)` append one decoder self-attention K/V step and return the current attention output. `needle_decoder_block_cached_step_f32` and `ctx:decoder_block_cached_step(cache, layer, row, encoder_out, enc_len)` run one decoder block step using cached self-attention plus regular cross-attention. `needle_decode_token_cached_step_f32` and `ctx:decode_token_cached_step(cache, token_id, encoder_out, enc_len)` run one token through all decoder layers at one cache position, then apply the final decoder norm. `needle_generate_tokens_greedy_cached[_filtered]` powers `ctx:generate_tokens(..., { use_cache = true })` and `ctx:generate(..., { use_cache = true })`. Tiny and real-checkpoint tests compare cached step outputs against uncached causal self-attention, uncached decoder block outputs, full uncached decoder outputs, and uncached greedy generation IDs. `benchmarks/kv_cache.lua` and `make bench-kv` track cached vs uncached greedy generation; current local run (`BENCH_ITERS=5 BENCH_MAX_NEW=8`) measured uncached 0.141489s, cached 0.096794s, speedup 1.462x.

### 7. Constrained Decoding

- [x] Add C/Lua token-filter primitive for constrained argmax.
- [x] Port or redesign tool-name/key constraints.
- [x] Build constraint state from tools JSON.
- [x] Constrain tool names.
- [x] Constrain argument keys.
- [x] Reject duplicate argument keys.
- [x] Enforce required argument keys before object close.
- [x] Keep values flexible.
- [x] Add broader malformed-output regression tests.

Done when: constrained generation preserves valid JSON/tool names on test cases.

### 8. Performance

- [x] Add timing harness.
- [x] Add aligned allocation.
- [x] Add AVX2/FMA kernels for dot products.
- [x] Add lazy float32 tensor cache for embeddings, projections, and tied logits.
- [x] Add AVX2/FMA kernels for matmul/projections.
- [x] Add aligned allocation churn counters to the runtime benchmark.
- [x] Reuse uncached greedy generation buffers and project only the last decoder row.
- [x] Reuse cached decoder step buffers inside cached greedy generation.
- [x] Reuse cached decoder block scratch buffers inside cached greedy generation.
- [x] Reuse cached self-attention scratch buffers inside cached greedy generation.
- [x] Reuse cached cross-attention scratch buffers inside cached greedy generation.
- [x] Precompute cached cross-attention K/V once per generation call.
- [x] Reuse encoder block and encoder self-attention scratch buffers across encoder layers.
- [x] Reuse decoder block, self-attention, and cross-attention scratch buffers across decoder layers.
- [x] Reuse uncached greedy decoder scratch buffers across generation steps.
- [x] Use encoder output buffer as encoder workspace to avoid one extra sequence buffer.
- [ ] Add optional AVX-VNNI path if useful for quantized kernels.
- [x] Add thread pool or decide single-thread target.
- [x] Profile memory bandwidth and allocation churn.

Done when: benchmark numbers are tracked and regressions are visible.

Current status: `benchmarks/kv_cache.lua` and `make bench-kv` provide a repeatable timing harness for cached vs uncached generation. `benchmarks/profile_runtime.lua` and `make bench-profile` profile encoder, uncached generation, and cached generation with timing, tokens/sec, aligned allocation churn, peak aligned bytes, and allocation MiB/sec. Runtime hot-path float buffers now use a 64-byte aligned allocator (`alloc_floats` / `calloc_floats` / `aligned_free`), including attention scratch buffers, decoder buffers, generation logits/decoder state, and KV cache K/V buffers. Attention score dot products now use a runtime-gated AVX2/FMA helper on x86 with scalar fallback elsewhere, encoder self-attention stores each query/key score row so the softmax/value pass does not recompute the same dots, the value accumulation/normalization pass uses AVX2/FMA helpers, and encoder prefill builds one RoPE sin/cos table per request instead of recomputing trigonometry for every layer and head. Tensor payloads lazily materialize and retain aligned float32 copies for embeddings, dense projections, and tied logits, avoiding repeated f16/f32 conversion while keeping projection accumulation numerically compatible with golden outputs. Dense float projections use a runtime-gated AVX2/FMA gather kernel with double accumulation for column dot products over row-major weights, while q8 projections use runtime-gated AVX2/FMA blocks that compute up to 32 output columns per input sweep from contiguous int8 weights, with scalar fallback for non-x86 or unsupported CPUs. The C runtime exposes aligned allocation plus dense/output q8 dispatch counters through Lua (`needle.memory_stats()` / `needle.reset_memory_stats()`), exposes opt-in encoder prefill timing counters (`needle.set_profile_enabled()` / `needle.profile_stats()`), and the KV/profile/q8 benchmarks print allocation churn per mode. Uncached greedy generation now reuses decoder/logit buffers for the whole call, projects only the last decoder row needed for next-token selection, and reuses full-decoder scratch buffers across generation steps; cached greedy generation reuses decoder step, decoder block, cached self-attention, and cross-attention scratch buffers across prompt and generated tokens. Cached generation also precomputes decoder cross-attention K/V once per generation call, avoiding repeated encoder K/V projections per token. `needle_encoder_state` lets embedders keep prefill output in C-owned memory and run decode without re-encoding. Encoder execution reuses block and self-attention scratch buffers across encoder layers and uses the caller output buffer as the active encoder workspace; full decoder execution reuses block, self-attention, and cross-attention scratch buffers across decoder layers. Tool-call constraints can run through `token_filter_raw`, avoiding per-step Lua token-history table allocation in constrained decode. The v1 embedding target is explicitly single-threaded: the C runtime does not create worker threads or own a thread pool, and host applications should parallelize with independent contexts/workers if needed. Current local `make bench-kv` run (`BENCH_ITERS=5 BENCH_MAX_NEW=8`) measured uncached 0.141489s with 115 aligned allocations / 1,669,120 allocated bytes, cached 0.096794s with 125 aligned allocations / 1,945,600 allocated bytes, speedup 1.462x. Current local profile for the active select-screen Needle tool snapshot (1,840-byte tools JSON, 464 encoder tokens) measured warm q8 encoder prefill at 0.389s without profiling and about 0.428s with encoder counters enabled; MCP in-game smoke measured 0.369–0.374s after restart. Per-iteration hotspots are attention value accumulation (~0.126s), attention score dot products (~0.109s), q/out projections (~0.049–0.051s each), and q/k norm plus table-backed RoPE (~0.014s). Current local `make example-tool-q8` smoke run with AVX2 q8, C-owned encoder state, raw tool constraints, and required/schema checks measured prefill 0.197856s, decode 0.085982s, total 0.283838s. Current local `BENCH_ITERS=5 BENCH_MAX_NEW=8 make bench-q8-stripped` measured q8 cached generation 12.355x faster than float.

### 9. Quantization

- [x] Decide runtime quantization target: int8 first, int4 later.
- [x] Extend exporter for quantized weights.
- [x] Add quantized matmul kernels.
- [x] Compare accuracy and speed against float32.
- [x] Keep float32 fallback.

Done when: quantized runtime passes quality tests and is measurably faster/smaller.

Current status: v1 quantization target is int8 first, int4 later. The first format is symmetric per-output-channel int8 for dense/projection kernels, stored as int8 weight tensors plus float32 scale tensors in metadata-compatible `NDLRTM1` records. The tied output projection also has an optional `embedding/embedding.q8` plus row-scale tensor; the original embedding remains present for token lookup. `scripts/export_needle_runtime.py --quantize-int8` and `make export-q8` write fallback float weights plus `.q8` / `.q8_scale` tensors; `make export-q8-stripped` replaces quantized float kernel payloads with one-byte placeholders so the q8 path can keep the original tensor names for dispatch while removing the large duplicate float payloads. Runtime dense projection automatically uses a q8 path when the q8 weight plus scale tensors are present, and tied output logits use q8 embedding rows when present; otherwise both fall back to the existing float32/f16 paths. The q8 projection loops use AVX2/FMA when available, compute up to 32 output columns per input sweep, and fall back to portable scalar code otherwise. `needle.memory_stats()` exposes dense and output q8/float/fallback dispatch counters, and q8 benchmarks print these counters so production smoke checks can verify dense and logits dispatch. `benchmarks/quant_compare.lua`, `make bench-q8`, and `make bench-q8-stripped` compare q8 vs float accuracy, speed, tensor bytes, generated IDs, and q8 dispatch counts; `benchmarks/quant_quality.lua` and `make bench-q8-quality` run a small multi-query quality sweep. Current local stripped smoke run (`BENCH_ITERS=5 BENCH_MAX_NEW=8`) measured tensor bytes 34,928,968 vs float 52,630,842, encoder max diff 0.211904049, matching cached generation IDs (`1,4,809,1`), and q8 cached generation 12.355x faster than float on that short case. Current local quality sweep measured 6/6 token matches across weather/timer/email/lights prompts with and without tools, match rate 1.00, worst encoder diff 0.211904049, and 1968 q8 projections / 0 float projections / 0 q8 fallbacks. Current local `make example-tool-q8` smoke with q8 output logits measured prefill 0.197856s, decode 0.085982s, total 0.283838s, with 20 q8 output projections / 0 float output projections / 0 output q8 fallbacks. `tests/test_quantized_runtime.lua` is wired into `make test-real` to check stripped q8 metadata, size reduction, dense and embedding q8 tensor dtypes, q8 dispatch counters, output logits q8 dispatch, encoder tolerance, and cached generation IDs. AVX-VNNI remains a possible later target after more quality benchmarks.

### 10. Production Hardening

- [x] Make ABI versioned.
- [x] Add deterministic error handling.
- [x] Add fuzz-ish tests for malformed files and JSON.
- [x] Add memory leak checks.
- [x] Add CI-friendly build commands.
- [x] Add packaging notes for Linux/macOS.
- [x] Document supported CPU features and fallback behavior.

Done when: runtime can be embedded by a LuaJIT app with documented failure modes.

Current status: `needle_abi_version()` is exported and Lua validates ABI 8 on load. Runtime APIs return structured error tables in Lua, successful operations clear or preserve OK status, and `tests/test_api.lua` covers representative deterministic error-state behavior. `tests/test_loader_errors.lua` mutates tiny runtime fixtures to cover invalid magic, truncated headers, unsupported format versions, trailing bytes, and invalid tensor dtypes. `tests/test_memory_stats.lua` exercises load, encode/decode, uncached generation, cached generation, and explicit KV cache lifecycle, then verifies aligned allocation active/current bytes return to baseline after handles close. `make test-ci` aliases the dependency-light CI target, while `make test-all` runs tiny plus real-checkpoint validation. README documents malformed-file failure modes, aligned allocator leak checks, Linux/macOS packaging notes, and AVX2/FMA runtime dispatch with scalar fallback.

## Open Decisions

- Whether to keep tokenizer inside `needle.bin` or split it into `tokenizer.bin` later. Current v1 embeds `NDLTOK1` tokenizer bytes.
- Whether first production target is float32-only or int8.
- Whether C runtime should parse tools JSON fully or accept a simplified Lua-prepared constraint table.
- Whether streaming should later support byte-accurate incremental SentencePiece decode state instead of per-token text chunks.
- Whether to support multiple loaded model instances in one process.
- Whether to replace the tokenizer's linear piece lookup with a hash table/trie before the first production benchmark.

## Current Environment Notes

- LuaJIT is available.
- GCC/`cc` is available.
- Clang is not installed.
- Target machine is Linux x86_64.
- CPU supports AVX2, FMA, and AVX-VNNI.
