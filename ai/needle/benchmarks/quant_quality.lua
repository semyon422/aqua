local needle = require("needle")

local float_model_path = arg[1] or "build/needle.bin"
local q8_model_path = arg[2] or "build/needle-q8-stripped.bin"
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

local function token_diff_index(a, b)
  local n = math.max(#a, #b)
  for i = 1, n do
    if a[i] ~= b[i] then
      return i
    end
  end
  return nil
end

local function max_abs_diff(a, b)
  local max_diff = 0.0
  local max_i = 1
  for i = 1, math.min(#a, #b) do
    local diff = math.abs(a[i] - b[i])
    if diff > max_diff then
      max_diff = diff
      max_i = i
    end
  end
  return max_diff, max_i
end

local tools_json = '[{"name":"get_weather","parameters":{"location":{"type":"string"},"unit":{"type":"string"}}},{"name":"set_timer","parameters":{"minutes":{"type":"number"}}},{"name":"send_email","parameters":{"recipient":{"type":"string"},"body":{"type":"string"}}}]'

local scenarios = {
  { name = "weather_short", query = "weather in Paris", tools = "[]", max_new = 4 },
  { name = "weather_tools", query = "weather in Paris", tools = tools_json, max_new = 8 },
  { name = "timer_tools", query = "set a timer for 10 minutes", tools = tools_json, max_new = 8 },
  { name = "email_tools", query = "email bob@example.com tomorrow", tools = tools_json, max_new = 8 },
  { name = "lights_no_tools", query = "Turn off the lights", tools = "[]", max_new = 8 },
  { name = "long_weather", query = "Please check whether it will rain in Paris tomorrow morning", tools = tools_json, max_new = 12 },
}

local limit = env_int("BENCH_CASES", #scenarios)
local max_enc_len = env_int("BENCH_MAX_ENC", 1024)

local tok = assert(needle.load_tokenizer(tokenizer_path))
local float_ctx = assert(needle.load(float_model_path))
local q8_ctx = assert(needle.load(q8_model_path))

local float_info = float_ctx:info()
local q8_info = q8_ctx:info()
local checked = 0
local matched = 0
local worst_encoder_diff = 0.0
local worst_encoder_case = ""
local total_q8_projections = 0
local total_float_projections = 0
local total_q8_fallbacks = 0

print(("float_model=%s"):format(float_model_path))
print(("q8_model=%s"):format(q8_model_path))
print(("float_tensor_bytes=%d q8_tensor_bytes=%d"):format(float_info.tensor_data_bytes, q8_info.tensor_data_bytes))

for i, scenario in ipairs(scenarios) do
  if i > limit then
    break
  end
  local src_ids = float_ctx:build_encoder_input(tok, scenario.query, scenario.tools, {
    max_enc_len = max_enc_len,
  })
  local prompt_ids = { 1 }
  local float_encoder = assert(float_ctx:encode_tokens(src_ids))
  local q8_encoder = assert(q8_ctx:encode_tokens(src_ids))
  local encoder_diff, encoder_i = max_abs_diff(float_encoder, q8_encoder)
  if encoder_diff > worst_encoder_diff then
    worst_encoder_diff = encoder_diff
    worst_encoder_case = scenario.name
  end

  local float_tokens = assert(float_ctx:generate_tokens(src_ids, prompt_ids, {
    max_new_tokens = scenario.max_new,
    use_cache = true,
  }))
  needle.reset_memory_stats()
  local q8_tokens = assert(q8_ctx:generate_tokens(src_ids, prompt_ids, {
    max_new_tokens = scenario.max_new,
    use_cache = true,
  }))
  local q8_stats = needle.memory_stats()
  total_q8_projections = total_q8_projections + q8_stats.dense_q8_projection_count
  total_float_projections = total_float_projections + q8_stats.dense_float_projection_count
  total_q8_fallbacks = total_q8_fallbacks + q8_stats.dense_q8_fallback_count
  local is_match = same(float_tokens, q8_tokens)
  local diff_i = token_diff_index(float_tokens, q8_tokens)
  checked = checked + 1
  if is_match then
    matched = matched + 1
  end

  print((
    "case=%s src_len=%d max_new=%d encoder_max_diff=%.9g encoder_index=%d tokens_match=%s diff_index=%s"
  ):format(
    scenario.name,
    #src_ids,
    scenario.max_new,
    encoder_diff,
    encoder_i,
    is_match and "true" or "false",
    diff_i and tostring(diff_i) or "-"
  ))
  print(("  float_tokens=%s"):format(table.concat(float_tokens, ",")))
  print(("  q8_tokens=%s"):format(table.concat(q8_tokens, ",")))
end

print(("summary_cases=%d matched=%d match_rate=%.2f worst_encoder_diff=%.9g worst_encoder_case=%s q8_projections=%d float_projections=%d q8_fallbacks=%d"):format(
  checked,
  matched,
  checked > 0 and matched / checked or 0,
  worst_encoder_diff,
  worst_encoder_case,
  total_q8_projections,
  total_float_projections,
  total_q8_fallbacks
))

q8_ctx:close()
float_ctx:close()
tok:close()
