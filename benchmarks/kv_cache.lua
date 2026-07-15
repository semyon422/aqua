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

local function stats_delta(fn)
  needle.reset_memory_stats()
  fn()
  return needle.memory_stats()
end

local query = os.getenv("BENCH_QUERY") or "weather in Paris"
local tools_json = os.getenv("BENCH_TOOLS") or "[]"
local max_new_tokens = env_int("BENCH_MAX_NEW", 8)
local iterations = env_int("BENCH_ITERS", 3)

local ctx = assert(needle.load(model_path))
local tok = assert(needle.load_tokenizer(tokenizer_path))

local src_ids = ctx:build_encoder_input(tok, query, tools_json, {
  max_enc_len = env_int("BENCH_MAX_ENC", 1024),
})
local prompt_ids = { 1 }

local uncached_ref = assert(ctx:generate_tokens(src_ids, prompt_ids, {
  max_new_tokens = max_new_tokens,
}))
local cached_ref = assert(ctx:generate_tokens(src_ids, prompt_ids, {
  max_new_tokens = max_new_tokens,
  use_cache = true,
}))
assert(same(uncached_ref, cached_ref), "cached generation IDs differ from uncached")

local uncached_total = 0.0
local uncached_stats = stats_delta(function()
  for _ = 1, iterations do
    local dt = elapsed(function()
      local ids = assert(ctx:generate_tokens(src_ids, prompt_ids, {
        max_new_tokens = max_new_tokens,
      }))
      assert(same(ids, uncached_ref), "uncached generation changed during benchmark")
    end)
    uncached_total = uncached_total + dt
  end
end)

local cached_total = 0.0
local cached_stats = stats_delta(function()
  for _ = 1, iterations do
    local dt = elapsed(function()
      local ids = assert(ctx:generate_tokens(src_ids, prompt_ids, {
        max_new_tokens = max_new_tokens,
        use_cache = true,
      }))
      assert(same(ids, cached_ref), "cached generation changed during benchmark")
    end)
    cached_total = cached_total + dt
  end
end)

local uncached_avg = uncached_total / iterations
local cached_avg = cached_total / iterations
local speedup = cached_avg > 0 and uncached_avg / cached_avg or 0

print(("model=%s"):format(model_path))
print(("src_len=%d prompt_len=%d max_new=%d iterations=%d"):format(#src_ids, #prompt_ids, max_new_tokens, iterations))
print(("uncached_avg_sec=%.6f"):format(uncached_avg))
print(("cached_avg_sec=%.6f"):format(cached_avg))
print(("speedup=%.3fx"):format(speedup))
print(("uncached_aligned_allocs=%d bytes=%d peak_bytes=%d"):format(
  uncached_stats.aligned_alloc_count,
  uncached_stats.aligned_alloc_total_bytes,
  uncached_stats.aligned_alloc_peak_bytes
))
print(("cached_aligned_allocs=%d bytes=%d peak_bytes=%d"):format(
  cached_stats.aligned_alloc_count,
  cached_stats.aligned_alloc_total_bytes,
  cached_stats.aligned_alloc_peak_bytes
))
print(("tokens=%s"):format(table.concat(cached_ref, ",")))

tok:close()
ctx:close()
