local needle = require("needle")

local model_path = arg[1] or "build/needle-q8-stripped.bin"
local tokenizer_path = arg[2] or "build/tokenizer.ndltok"

local query = os.getenv("NEEDLE_QUERY") or "weather in Paris"
local tools_json = os.getenv("NEEDLE_TOOLS") or [[
[
  {
    "name": "get_weather",
    "description": "Get current weather for a city.",
    "parameters": {
      "type": "object",
      "properties": {
        "location": { "type": "string" },
        "unit": { "type": "string", "enum": ["celsius", "fahrenheit"] }
      },
      "required": ["location", "unit"]
    }
  },
  {
    "name": "set_timer",
    "description": "Set a timer in minutes.",
    "parameters": {
      "type": "object",
      "properties": {
        "minutes": { "type": "number" }
      },
      "required": ["minutes"]
    }
  }
]
]]

local ctx, err = needle.load(model_path)
if not ctx or not ctx:is_loaded() then
  error(("load failed [%s]: %s"):format(err and err.name or "UNKNOWN", err and err.message or ""))
end

local chunks = {}
local token_count = 0
local start = os.clock()
local text, gen_err = ctx:generate_stream(query, tools_json, function(chunk)
  chunks[#chunks + 1] = chunk
  io.write(chunk)
  io.flush()
  return true
end, {
  tokenizer_path = tokenizer_path,
  max_new_tokens = 32,
  constrained = true,
  use_cache = true,
  on_token = function()
    token_count = token_count + 1
    return true
  end,
})
local elapsed = os.clock() - start
io.write("\n")

if not text then
  ctx:close()
  error(("generate failed [%s]: %s"):format(gen_err.name, gen_err.message))
end

ctx:close()

print(("final: %s"):format(text))
print(("chunks_match: %s"):format(table.concat(chunks) == text and "true" or "false"))
print(("tokens: %d"):format(token_count))
print(("elapsed_sec: %.6f"):format(elapsed))
