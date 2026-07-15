local needle = require("needle")

local model_path = arg[1] or "build/needle.bin"
local tokenizer_path = arg[2] or "build/tokenizer.ndltok"
local query = arg[3] or "weather in Paris"

local tools_json = [[
[
  {
    "name": "get_weather",
    "description": "Get current weather for a city.",
    "parameters": {
      "type": "object",
      "properties": {
        "location": { "type": "string" },
        "unit": { "type": "string" }
      }
    }
  },
  {
    "name": "set_timer",
    "description": "Set a timer in minutes.",
    "parameters": {
      "type": "object",
      "properties": {
        "minutes": { "type": "number" }
      }
    }
  }
]
]]

local function compact_json(text)
  local out = {}
  local in_string = false
  local escaped = false
  for i = 1, #text do
    local ch = text:sub(i, i)
    if in_string then
      out[#out + 1] = ch
      if escaped then
        escaped = false
      elseif ch == "\\" then
        escaped = true
      elseif ch == '"' then
        in_string = false
      end
    elseif ch == '"' then
      in_string = true
      out[#out + 1] = ch
    elseif ch ~= " " and ch ~= "\t" and ch ~= "\n" and ch ~= "\r" then
      out[#out + 1] = ch
    end
  end
  return table.concat(out)
end

local ctx, err = needle.load(model_path)
if not ctx or not ctx:is_loaded() then
  error(("load failed [%s]: %s"):format(err and err.name or "UNKNOWN", err and err.message or ""))
end

local tok = assert(needle.load_tokenizer(tokenizer_path))
local compact_tools = compact_json(tools_json)

print(("query: %s"):format(query))
print(("tools: %s"):format(compact_tools))

local src_ids = ctx:build_encoder_input(tok, query, compact_tools)
local prompt_ids = { 1 }
local constraints = assert(needle.build_tool_call_constraints(compact_tools, tok, {
  eos_token_id = 1,
}))

needle.reset_memory_stats()
local prefill_start = os.clock()
local encoder_state = assert(ctx:encode_tokens_state(src_ids))
local prefill_sec = os.clock() - prefill_start
local prefill_stats = needle.memory_stats()

needle.reset_memory_stats()
local generate_start = os.clock()
local generated, gen_err = ctx:generate_tokens_from_state(encoder_state, prompt_ids, {
  max_new_tokens = 32,
  eos_token_id = 1,
  token_filter_raw = constraints:token_filter_raw(),
})
local decode_sec = os.clock() - generate_start
local generate_stats = needle.memory_stats()

if not generated then
  tok:close()
  ctx:close()
  error(("generate failed [%s]: %s"):format(gen_err.name, gen_err.message))
end

local result_ids = {}
for i = #prompt_ids + 1, #generated do
  local id = generated[i]
  if id == 1 then
    break
  end
  result_ids[#result_ids + 1] = id
end

local text = assert(tok:decode(result_ids))
if text:sub(1, 11) == "<tool_call>" then
  text = text:sub(12):gsub("^%s+", "")
end

tok:close()
encoder_state:close()
ctx:close()

print(("prefill_sec: %.6f"):format(prefill_sec))
print(("decode_sec: %.6f"):format(decode_sec))
print(("total_sec: %.6f"):format(prefill_sec + decode_sec))
print(("prefill_q8_projections: %d float_projections: %d q8_fallbacks: %d"):format(
  prefill_stats.dense_q8_projection_count,
  prefill_stats.dense_float_projection_count,
  prefill_stats.dense_q8_fallback_count
))
print(("generate_q8_projections: %d float_projections: %d q8_fallbacks: %d"):format(
  generate_stats.dense_q8_projection_count,
  generate_stats.dense_float_projection_count,
  generate_stats.dense_q8_fallback_count
))
print("output:")
print(text)
