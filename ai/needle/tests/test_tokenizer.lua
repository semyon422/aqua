local needle = require("needle")

local tokenizer_path = arg[1]
assert(tokenizer_path and tokenizer_path ~= "", "tokenizer path required")

local tok, err = needle.load_tokenizer(tokenizer_path)
assert(tok ~= nil, "tokenizer loader returned nil")
assert(err == nil or err.code == needle.errors.OK, err and err.message or "tokenizer load failed")
assert(tok:vocab_size() == 8192, "unexpected vocab size")

local cases = {
  { "weather in Paris", { 1149, 362, 953, 6348 } },
  { "hello world", { 706, 8055, 363, 5338, 745 } },
  { '[{"name":"get_weather"}]', { 356, 294, 264, 358, 8062, 1331, 8039, 8059, 8072 } },
  { "<tool_call>", { 8041, 4 } },
  { "<tools>", { 8041, 5 } },
  { "Turn off the lights", { 5306, 762, 302, 2457 } },
  { "set a timer for 10 minutes", { 796, 289, 849, 345, 1216, 662 } },
  { "email bob@example.com tomorrow", { 635, 349, 1872, 8181, 5319, 8063, 869, 4402 } },
}

local function same(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

for _, case in ipairs(cases) do
  local text, expected = case[1], case[2]
  local ids, enc_err = tok:encode(text)
  assert(ids ~= nil, enc_err and enc_err.message or "encode failed")
  assert(same(ids, expected), "ids mismatch for " .. text)
  local decoded, dec_err = tok:decode(ids)
  assert(decoded ~= nil, dec_err and dec_err.message or "decode failed")
  assert(decoded == text, ("decode mismatch for %s: %s"):format(text, decoded))
end

assert(tok:token_text(362) == " in", "token_text must preserve leading SentencePiece space")
assert(tok:token_text(356) == ' [{"', "token_text structural token mismatch")

local function token_id_for_text(text)
  for id = 0, tok:vocab_size() - 1 do
    if tok:token_text(id) == text then
      return id
    end
  end
  return nil
end

local function as_set(values)
  local out = {}
  for _, value in ipairs(values or {}) do
    out[value] = true
  end
  return out
end

local function has_token_start(values, ch)
  for _, id in ipairs(values or {}) do
    local text = tok:token_text(id)
    if text:sub(1, 1) == ch then
      return true
    end
  end
  return false
end

local tools_json = '[{"name":"get_weather","parameters":{"type":"object","properties":{"location":{"type":"string"},"unit":{"type":"string","enum":["celsius","fahrenheit"]}},"required":["location","unit"]}},{"name":"set_timer","parameters":{"type":"object","properties":{"minutes":{"type":"number"}},"required":["minutes"]}}]'
local constraints = assert(needle.build_tool_call_constraints(tools_json, tok))
constraints:sync(assert(tok:encode('[{"name":"')))
local name_allowed = as_set(assert(constraints:allowed_token_ids()))
assert(name_allowed[token_id_for_text("get")], "tool-name constraint should allow get_weather prefix")
assert(name_allowed[token_id_for_text("set")], "tool-name constraint should allow set_timer prefix")
assert(not name_allowed[token_id_for_text(" location")], "tool-name constraint should reject unrelated leading-space token")

constraints = assert(needle.build_tool_call_constraints(tools_json, tok))
constraints:sync(assert(tok:encode('[{"name":"get_weather","arguments":{"')))
local weather_key_allowed = as_set(assert(constraints:allowed_token_ids()))
assert(weather_key_allowed[token_id_for_text("location")], "get_weather should allow location key")
assert(weather_key_allowed[token_id_for_text("unit")], "get_weather should allow unit key")
assert(not weather_key_allowed[token_id_for_text("minutes")], "get_weather should reject set_timer key")
assert(not weather_key_allowed[token_id_for_text(" location")], "arg-key constraint should reject leading-space key token")

constraints = assert(needle.build_tool_call_constraints(tools_json, tok))
constraints:sync(assert(tok:encode('[{"name":"set_timer","arguments":{"')))
local timer_key_allowed = as_set(assert(constraints:allowed_token_ids()))
assert(timer_key_allowed[token_id_for_text("minutes")], "set_timer should allow minutes key")
assert(not timer_key_allowed[token_id_for_text("location")], "set_timer should reject get_weather key")

local reordered_tools_json = '[{"parameters":{"type":"object","properties":{"rate":{"type":"number"}},"required":["rate"]},"name":"set_playback_rate"},{"parameters":{"type":"object","properties":{"mode":{"type":"string","enum":["save"]}},"required":["mode"]},"name":"capture_screenshot"}]'
constraints = assert(needle.build_tool_call_constraints(reordered_tools_json, tok))
constraints:sync(assert(tok:encode('[{"name":"set_playback_rate","arguments":{"')))
local reordered_key_allowed = as_set(assert(constraints:allowed_token_ids()))
assert(reordered_key_allowed[token_id_for_text("rate")], "tool constraints should not depend on object field order")
assert(not reordered_key_allowed[token_id_for_text("mode")], "field order should not associate parameters with the next tool")

constraints = assert(needle.build_tool_call_constraints(tools_json, tok, { eos_token_id = 1 }))
constraints:sync(assert(tok:encode('[{"name":"get_weather","arguments":{"location":"Paris"}}]')))
local done_allowed = assert(constraints:allowed_token_ids())
assert(#done_allowed == 1 and done_allowed[1] == 1, "completed tool-call JSON should force EOS")

constraints = assert(needle.build_tool_call_constraints(tools_json, tok, { eos_token_id = 1 }))
constraints:sync(assert(tok:encode('[{"name":"get_weather","arguments":{"location":"Paris with ] and { chars","')))
local after_value_allowed = as_set(assert(constraints:allowed_token_ids()))
assert(after_value_allowed[token_id_for_text("unit")], "arg-key constraint should resume after string values")
assert(not after_value_allowed[token_id_for_text("minutes")], "arg-key constraint after value should use current tool schema")
assert(not after_value_allowed[token_id_for_text("location")], "arg-key constraint should reject duplicate keys")

constraints = assert(needle.build_tool_call_constraints(tools_json, tok, { eos_token_id = 1 }))
constraints:sync(assert(tok:encode('[{"name":"get_weather","arguments":{"location":"Paris"')))
local missing_required_allowed = assert(constraints:allowed_token_ids())
assert(has_token_start(missing_required_allowed, ","), "missing required key should allow comma")
assert(not has_token_start(missing_required_allowed, "}"), "missing required key should reject object close")

constraints = assert(needle.build_tool_call_constraints(tools_json, tok, { eos_token_id = 1 }))
constraints:sync(assert(tok:encode('[{"name":"get_weather","arguments":{"unit":"')))
local unit_allowed = as_set(assert(constraints:allowed_token_ids()))
assert(unit_allowed[token_id_for_text("celsius")], "enum value should allow celsius")
assert(unit_allowed[token_id_for_text("fahrenheit")], "enum value should allow fahrenheit")
assert(not unit_allowed[token_id_for_text("clothing")], "enum value should reject unrelated token")

constraints = assert(needle.build_tool_call_constraints(tools_json, tok, { eos_token_id = 1 }))
constraints:sync(assert(tok:encode('[{"name":"get_weather","arguments":{"unit":"cloth')))
local bad_unit_allowed = assert(constraints:allowed_token_ids())
assert(#bad_unit_allowed == 1 and bad_unit_allowed[1] == 1, "unknown enum prefix should fail closed")

constraints = assert(needle.build_tool_call_constraints(tools_json, tok, { eos_token_id = 1 }))
constraints:sync(assert(tok:encode('[{"name":"get_weather","arguments":{"location":"Paris","unit":"celsius"')))
local all_required_allowed = assert(constraints:allowed_token_ids())
assert(has_token_start(all_required_allowed, "}"), "all required keys should allow object close")
assert(not has_token_start(all_required_allowed, ","), "no remaining keys should reject trailing comma")

constraints = assert(needle.build_tool_call_constraints(tools_json, tok, { eos_token_id = 1 }))
constraints:sync(assert(tok:encode('[{"name":"set_timer","arguments":{"minutes":')))
local number_start_allowed = as_set(assert(constraints:allowed_token_ids()))
local number_comma_id = token_id_for_text("5,")
if number_comma_id then
  assert(not number_start_allowed[number_comma_id], "number tokens should not cross into an unchecked delimiter")
end

constraints = assert(needle.build_tool_call_constraints(tools_json, tok, { eos_token_id = 1 }))
constraints:sync(assert(tok:encode('[{"name":"set_timer","arguments":{"minutes":5')))
local number_required_allowed = assert(constraints:allowed_token_ids())
assert(has_token_start(number_required_allowed, "}"), "number required key should allow object close after value")
assert(not has_token_start(number_required_allowed, ","), "single number key should reject trailing comma")

tok:close()
print("test_tokenizer.lua: ok")
