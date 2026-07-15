local needle = require("needle")

local float_model = arg[1]
local q8_model = arg[2]
local tokenizer_path = arg[3]
assert(float_model and float_model ~= "", "float model path required")
assert(q8_model and q8_model ~= "", "q8 model path required")
assert(tokenizer_path and tokenizer_path ~= "", "tokenizer path required")

local function same(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

local tok = assert(needle.load_tokenizer(tokenizer_path))
local float_ctx = assert(needle.load(float_model))
local q8_ctx = assert(needle.load(q8_model))

local float_info = float_ctx:info()
local q8_info = q8_ctx:info()
assert(q8_info.metadata_json:match("q8_symmetric_per_output_channel"), "q8 metadata marker missing")
assert(q8_info.metadata_json:match('"stripped_float_kernels":true'), "stripped q8 metadata marker missing")
assert(q8_info.tensor_data_bytes < float_info.tensor_data_bytes, "stripped q8 tensor bytes should be smaller than float")

local q_idx = assert(q8_ctx:find_tensor("encoder/layers/EncoderBlock_0/self_attn/q_proj/kernel.q8"))
local s_idx = assert(q8_ctx:find_tensor("encoder/layers/EncoderBlock_0/self_attn/q_proj/kernel.q8_scale"))
assert(q8_ctx:tensor(q_idx).dtype_name == "i8", "q8 tensor dtype mismatch")
assert(q8_ctx:tensor(s_idx).dtype_name == "f32", "q8 scale tensor dtype mismatch")

local src = float_ctx:build_encoder_input(tok, "weather in Paris", "[]", { max_enc_len = 1024 })
needle.reset_memory_stats()
local float_encoder = assert(float_ctx:encode_tokens(src))
local float_stats = needle.memory_stats()
assert(float_stats.dense_q8_projection_count == 0, "float model should not use q8 projections")
assert(float_stats.dense_float_projection_count > 0, "float model should use float projections")
assert(float_stats.dense_q8_fallback_count == float_stats.dense_float_projection_count, "float model fallback count should match float projections")

needle.reset_memory_stats()
local q8_encoder = assert(q8_ctx:encode_tokens(src))
local q8_stats = needle.memory_stats()
assert(q8_stats.dense_q8_projection_count > 0, "q8 model should use q8 projections")
assert(q8_stats.dense_float_projection_count == 0, "q8 encoder should not use float dense projections")
assert(q8_stats.dense_q8_fallback_count == 0, "q8 encoder should not fall back for dense projections")
local max_diff = 0.0
for i = 1, #float_encoder do
  local diff = math.abs(float_encoder[i] - q8_encoder[i])
  if diff > max_diff then
    max_diff = diff
  end
end
assert(max_diff <= 0.3, ("q8 encoder max diff %.9g exceeds tolerance"):format(max_diff))

local prompt = { 1 }
local float_tokens = assert(float_ctx:generate_tokens(src, prompt, {
  max_new_tokens = 4,
  use_cache = true,
}))
local q8_tokens = assert(q8_ctx:generate_tokens(src, prompt, {
  max_new_tokens = 4,
  use_cache = true,
}))
assert(same(float_tokens, q8_tokens), "q8 cached generation IDs should match float smoke case")

q8_ctx:close()
float_ctx:close()
tok:close()

print(("test_quantized_runtime.lua: ok max_diff=%.9g tensor_bytes=%d"):format(max_diff, q8_info.tensor_data_bytes))
