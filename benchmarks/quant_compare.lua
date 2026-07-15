local needle = require("needle")

local float_model_path = arg[1] or "build/needle.bin"
local q8_model_path = arg[2] or "build/needle-q8.bin"
local tokenizer_path = arg[3] or "build/tokenizer.ndltok"

local function env_int(name, fallback)
  local value = tonumber(os.getenv(name) or "")
  if value == nil or value <= 0 then
    return fallback
  end
  return math.floor(value)
end

local function same(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

local function elapsed(fn)
  collectgarbage("collect")
  local start = os.clock()
  local result = { fn() }
  return os.clock() - start, unpack(result)
end

local function avg_time(iterations, fn)
  local total = 0.0
  for _ = 1, iterations do
    local dt = elapsed(fn)
    total = total + dt
  end
  return total / iterations
end

local query = os.getenv("BENCH_QUERY") or "weather in Paris"
local tools_json = os.getenv("BENCH_TOOLS") or "[]"
local max_new_tokens = env_int("BENCH_MAX_NEW", 4)
local iterations = env_int("BENCH_ITERS", 3)

local tok = assert(needle.load_tokenizer(tokenizer_path))
local float_ctx = assert(needle.load(float_model_path))
local q8_ctx = assert(needle.load(q8_model_path))

local src_ids = float_ctx:build_encoder_input(tok, query, tools_json, {
  max_enc_len = env_int("BENCH_MAX_ENC", 1024),
})
local prompt_ids = { 1 }

local float_encoder = assert(float_ctx:encode_tokens(src_ids))
local q8_encoder = assert(q8_ctx:encode_tokens(src_ids))
local max_diff = 0.0
local max_i = 1
for i = 1, #float_encoder do
  local diff = math.abs(float_encoder[i] - q8_encoder[i])
  if diff > max_diff then
    max_diff = diff
    max_i = i
  end
end

local float_tokens = assert(float_ctx:generate_tokens(src_ids, prompt_ids, {
  max_new_tokens = max_new_tokens,
  use_cache = true,
}))
needle.reset_memory_stats()
local q8_tokens = assert(q8_ctx:generate_tokens(src_ids, prompt_ids, {
  max_new_tokens = max_new_tokens,
  use_cache = true,
}))
local q8_reference_stats = needle.memory_stats()

local float_avg = avg_time(iterations, function()
  local ids = assert(float_ctx:generate_tokens(src_ids, prompt_ids, {
    max_new_tokens = max_new_tokens,
    use_cache = true,
  }))
  assert(same(ids, float_tokens), "float generation changed during quant benchmark")
end)

local q8_avg = avg_time(iterations, function()
  local ids = assert(q8_ctx:generate_tokens(src_ids, prompt_ids, {
    max_new_tokens = max_new_tokens,
    use_cache = true,
  }))
  assert(same(ids, q8_tokens), "q8 generation changed during quant benchmark")
end)

local float_info = float_ctx:info()
local q8_info = q8_ctx:info()
local speedup = q8_avg > 0 and float_avg / q8_avg or 0

print(("float_model=%s"):format(float_model_path))
print(("q8_model=%s"):format(q8_model_path))
print(("float_tensor_bytes=%d q8_tensor_bytes=%d"):format(float_info.tensor_data_bytes, q8_info.tensor_data_bytes))
print(("src_len=%d max_new=%d iterations=%d"):format(#src_ids, max_new_tokens, iterations))
print(("encoder_max_diff=%.9g index=%d"):format(max_diff, max_i))
print(("float_cached_avg_sec=%.6f"):format(float_avg))
print(("q8_cached_avg_sec=%.6f"):format(q8_avg))
print(("q8_speedup=%.3fx"):format(speedup))
print(("q8_reference_dense_q8_projections=%d float_projections=%d q8_fallbacks=%d"):format(
  q8_reference_stats.dense_q8_projection_count,
  q8_reference_stats.dense_float_projection_count,
  q8_reference_stats.dense_q8_fallback_count
))
print(("float_tokens=%s"):format(table.concat(float_tokens, ",")))
print(("q8_tokens=%s"):format(table.concat(q8_tokens, ",")))
print(("tokens_match=%s"):format(same(float_tokens, q8_tokens) and "true" or "false"))

q8_ctx:close()
float_ctx:close()
tok:close()
