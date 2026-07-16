local needle = require("needle")

local fixture = arg[1]
assert(fixture and fixture ~= "", "fixture path required")

local ctx, err = needle.load(fixture)
assert(ctx ~= nil, "loader returned nil")
assert(err == nil or err.code == needle.errors.OK, err and err.message or "load failed")

local info = ctx:info()
assert(info.tensor_count == 28, "fixture tensor count mismatch")

local cfg = assert(ctx:config())
assert(cfg.vocab_size == 2, "config vocab mismatch")
assert(cfg.d_model == 2, "config d_model mismatch")
assert(cfg.num_heads == 1, "config num_heads mismatch")
assert(cfg.num_encoder_layers == 1, "config encoder layers mismatch")
assert(cfg.num_decoder_layers == 1, "config decoder layers mismatch")
assert(cfg.rope_theta == 10000, "config rope theta mismatch")
assert(cfg.dtype == "float32", "config dtype mismatch")
assert(cfg.activation == "swiglu", "config activation mismatch")
assert(cfg.no_feedforward == true, "config no_feedforward mismatch")

local embedding_index = ctx:find_tensor("embedding/embedding")
assert(embedding_index == 1, "embedding tensor should be first in fixture")

local embedding = ctx:tensor(embedding_index)
assert(embedding.name == "embedding/embedding", "embedding name mismatch")
assert(embedding.dtype == needle.dtypes.F32, "embedding dtype mismatch")
assert(embedding.dtype_name == "f32", "embedding dtype name mismatch")
assert(#embedding.shape == 2, "embedding rank mismatch")
assert(embedding.shape[1] == 2 and embedding.shape[2] == 2, "embedding shape mismatch")
assert(embedding.nbytes == 16, "embedding byte size mismatch")

local row0 = assert(ctx:embedding(0))
assert(#row0 == 2, "embedding row width mismatch")
assert(row0[1] == 1.0 and row0[2] == 2.0, "embedding row 0 mismatch")

local row1 = assert(ctx:embedding(1))
assert(row1[1] == 3.0 and row1[2] == 4.0, "embedding row 1 mismatch")

local logits = assert(ctx:output_projection({
  1.0, 1.0,
  2.0, -1.0,
}, 2))
assert(#logits == 4, "tiny logits length mismatch")
assert(logits[1] == 3.0 and logits[2] == 7.0 and logits[3] == 0.0 and logits[4] == 2.0, "tiny logits mismatch")

local function approx(a, b, eps)
  return math.abs(a - b) <= (eps or 1e-5)
end

local function norm2(a, b)
  local inv = 1.0 / math.sqrt((a * a + b * b) / 2.0 + 1e-6)
  return a * inv, b * inv
end

local function softmax2(a, b)
  local m = math.max(a, b)
  local ea, eb = math.exp(a - m), math.exp(b - m)
  local z = ea + eb
  return ea / z, eb / z
end

local attn = assert(ctx:encoder_self_attention(0, {
  1.0, 0.0,
  0.0, 1.0,
}, 2))

local q0x, q0y = norm2(1.0, 0.0)
local q1x, q1y = norm2(0.0, 1.0)
local c, s = math.cos(1.0), math.sin(1.0)
local k0x, k0y = q0x, q0y
local k1x, k1y = q1x * c - q1y * s, q1y * c + q1x * s
q1x, q1y = k1x, k1y

local inv_sqrt2 = 1.0 / math.sqrt(2.0)
local a00 = (q0x * k0x + q0y * k0y) * inv_sqrt2
local a01 = (q0x * k1x + q0y * k1y) * inv_sqrt2
local w00, w01 = softmax2(a00, a01)
local a10 = (q1x * k0x + q1y * k0y) * inv_sqrt2
local a11 = (q1x * k1x + q1y * k1y) * inv_sqrt2
local w10, w11 = softmax2(a10, a11)
local expected_attn = {
  w00, w01,
  w10, w11,
}
for i = 1, #expected_attn do
  assert(approx(attn[i], expected_attn[i], 1e-5), ("encoder self-attn mismatch at %d: %.9g vs %.9g"):format(i, attn[i], expected_attn[i]))
end

local missing = ctx:find_tensor("does/not/exist")
assert(missing == nil, "missing tensor should return nil")

local cache, cache_err = ctx:create_kv_cache(4)
assert(cache ~= nil, cache_err and cache_err.message or "KV cache creation failed")
local cache_info = cache:info()
assert(cache_info.max_tokens == 4, "KV cache max_tokens mismatch")
assert(cache_info.token_count == 0, "KV cache initial token_count mismatch")
assert(cache_info.layers == 1, "KV cache layer count mismatch")
assert(cache_info.kv_heads == 1, "KV cache kv_heads mismatch")
assert(cache_info.head_dim == 2, "KV cache head_dim mismatch")
assert(cache_info.bytes == 64, "KV cache byte size mismatch")

local ok, set_err = cache:set_token_count(3)
assert(ok == true, set_err and set_err.message or "KV cache set_token_count failed")
assert(cache:info().token_count == 3, "KV cache token_count did not update")
local bad, bad_err, bad_rc = cache:set_token_count(5)
assert(bad == nil, "KV cache out-of-bounds token count should fail")
assert(bad_rc == needle.errors.INVALID_ARGUMENT, "KV cache bounds error code mismatch")
assert(bad_err.name == "INVALID_ARGUMENT", "KV cache bounds error name mismatch")
assert(cache:reset() == true, "KV cache reset failed")
assert(cache:info().token_count == 0, "KV cache reset did not clear token_count")

local decoder_input = {
  1.0, 0.0,
  0.0, 1.0,
}
local uncached_decoder = assert(ctx:decoder_self_attention(0, decoder_input, 2))
local cached_step_1 = assert(ctx:decoder_self_attention_cached_step(cache, 0, { 1.0, 0.0 }))
assert(cache:info().token_count == 1, "cached self-attention did not append first token")
local cached_step_2 = assert(ctx:decoder_self_attention_cached_step(cache, 0, { 0.0, 1.0 }))
assert(cache:info().token_count == 2, "cached self-attention did not append second token")
for i = 1, 2 do
  assert(approx(cached_step_1[i], uncached_decoder[i], 1e-5), ("cached step 1 mismatch at %d: %.9g vs %.9g"):format(i, cached_step_1[i], uncached_decoder[i]))
  assert(approx(cached_step_2[i], uncached_decoder[2 + i], 1e-5), ("cached step 2 mismatch at %d: %.9g vs %.9g"):format(i, cached_step_2[i], uncached_decoder[2 + i]))
end

cache:close()

local no_cache, no_cache_err = ctx:create_kv_cache(0)
assert(no_cache == nil, "zero-sized KV cache should fail")
assert(no_cache_err.code == needle.errors.INVALID_ARGUMENT, "zero-sized KV cache error code mismatch")

ctx:close()
print("test_model.lua: ok")
