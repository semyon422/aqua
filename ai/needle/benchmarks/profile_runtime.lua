local needle = require("needle")

local model_path = arg[1] or "build/needle.bin"
local tokenizer_path = arg[2] or "build/tokenizer.ndltok"

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

local function mib(bytes)
  return bytes / (1024 * 1024)
end

local function profile(label, iterations, tokens_per_iter, fn)
  local total = 0.0
  needle.reset_memory_stats()
  for _ = 1, iterations do
    local dt = elapsed(fn)
    total = total + dt
  end
  local stats = needle.memory_stats()
  local avg = total / iterations
  local tokens_per_sec = total > 0 and (tokens_per_iter * iterations) / total or 0
  local alloc_mib = mib(stats.aligned_alloc_total_bytes)
  local alloc_mib_per_sec = total > 0 and alloc_mib / total or 0
  print(("%s_avg_sec=%.6f"):format(label, avg))
  print(("%s_tokens_per_sec=%.2f"):format(label, tokens_per_sec))
  print(("%s_aligned_allocs=%d bytes=%d peak_bytes=%d alloc_mib_per_sec=%.2f"):format(
    label,
    stats.aligned_alloc_count,
    stats.aligned_alloc_total_bytes,
    stats.aligned_alloc_peak_bytes,
    alloc_mib_per_sec
  ))
end

local query = os.getenv("BENCH_QUERY") or "weather in Paris"
local tools_json = os.getenv("BENCH_TOOLS") or "[]"
local max_new_tokens = env_int("BENCH_MAX_NEW", 8)
local iterations = env_int("BENCH_ITERS", 5)
local max_enc_len = env_int("BENCH_MAX_ENC", 1024)
local profile_encoder_ops = os.getenv("BENCH_PROFILE_ENCODER") == "1"

local ctx = assert(needle.load(model_path))
local tok = assert(needle.load_tokenizer(tokenizer_path))
local info = ctx:info()
local cfg = assert(ctx:config())

local src_ids = ctx:build_encoder_input(tok, query, tools_json, {
  max_enc_len = max_enc_len,
})
local prompt_ids = { 1 }

-- Warm tensor caches before measurement so allocation churn reflects each runtime path,
-- not one-time f16/f32 materialization.
assert(ctx:generate_tokens(src_ids, prompt_ids, {
  max_new_tokens = max_new_tokens,
}))
local uncached_ref = assert(ctx:generate_tokens(src_ids, prompt_ids, {
  max_new_tokens = max_new_tokens,
}))
local cached_ref = assert(ctx:generate_tokens(src_ids, prompt_ids, {
  max_new_tokens = max_new_tokens,
  use_cache = true,
}))
assert(same(uncached_ref, cached_ref), "cached generation IDs differ from uncached")

print(("model=%s"):format(model_path))
print(("tensor_data_mib=%.2f tokenizer_mib=%.2f"):format(mib(info.tensor_data_bytes), mib(info.tokenizer_bytes)))
print(("d_model=%d enc_layers=%d dec_layers=%d vocab=%d"):format(
  cfg.d_model,
  cfg.num_encoder_layers,
  cfg.num_decoder_layers,
  cfg.vocab_size
))
print(("src_len=%d prompt_len=%d max_new=%d iterations=%d"):format(#src_ids, #prompt_ids, max_new_tokens, iterations))

if profile_encoder_ops then
  needle.set_profile_enabled(true)
  needle.reset_profile_stats()
end
profile("encoder", iterations, #src_ids, function()
  local out = assert(ctx:encode_tokens(src_ids))
  assert(#out == #src_ids * cfg.d_model, "encoder output length mismatch")
end)
if profile_encoder_ops then
  needle.set_profile_enabled(false)
  local stats = needle.profile_stats()
  local names = {}
  for name in pairs(stats) do
    if name:match("_seconds$") then names[#names + 1] = name end
  end
  table.sort(names)
  for _, name in ipairs(names) do
    print(("profile_%s=%.6f"):format(name:gsub("_seconds$", ""), stats[name]))
  end
end

profile("uncached_generate", iterations, max_new_tokens, function()
  local ids = assert(ctx:generate_tokens(src_ids, prompt_ids, {
    max_new_tokens = max_new_tokens,
  }))
  assert(same(ids, uncached_ref), "uncached generation changed during profile")
end)

profile("cached_generate", iterations, max_new_tokens, function()
  local ids = assert(ctx:generate_tokens(src_ids, prompt_ids, {
    max_new_tokens = max_new_tokens,
    use_cache = true,
  }))
  assert(same(ids, cached_ref), "cached generation changed during profile")
end)

print(("tokens=%s"):format(table.concat(cached_ref, ",")))

tok:close()
ctx:close()
