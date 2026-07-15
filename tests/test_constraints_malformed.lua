local needle = require("needle")

local tokenizer_path = arg[1]
assert(tokenizer_path and tokenizer_path ~= "", "tokenizer path required")

local tok = assert(needle.load_tokenizer(tokenizer_path))
local eos_token_id = 1

local tools_json = '[{"name":"get_weather","parameters":{"location":{"type":"string"},"unit":{"type":"string"}}},{"name":"set_timer","parameters":{"minutes":{"type":"number"}}}]'

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

local function sync_allowed(text)
  local constraints = assert(needle.build_tool_call_constraints(tools_json, tok, { eos_token_id = eos_token_id }))
  constraints:sync(assert(tok:encode(text)))
  return constraints:allowed_token_ids()
end

local function assert_only_eos(values, label)
  assert(values ~= nil, label .. " should fail closed")
  assert(#values == 1 and values[1] == eos_token_id, label .. " should allow only EOS")
end

assert_only_eos(sync_allowed('[{"name":"get_x'), "unknown tool-name prefix")
assert_only_eos(sync_allowed('[{"name":"get_weather","arguments":{"locx'), "unknown argument-key prefix")
assert_only_eos(sync_allowed('[{"name":"unknown_tool","arguments":{"'), "argument key for unknown tool")
assert_only_eos(sync_allowed('[{"name":"get_weather","arguments":{"location":"Paris"}}]garbage'), "completed JSON with trailing garbage")

local after_escaped_value = as_set(assert(sync_allowed('[{"name":"get_weather","arguments":{"location":"Paris with \\"quoted\\" ] and { chars","')))
assert(after_escaped_value[token_id_for_text("unit")], "escaped quotes in string value should keep arg-key constraints usable")
assert(not after_escaped_value[token_id_for_text("minutes")], "escaped value should not switch tool schemas")

local timer_key_allowed = as_set(assert(sync_allowed('[{"name":"set_timer","arguments":{"')))
assert(timer_key_allowed[token_id_for_text("minutes")], "valid prefix should still allow timer keys")
assert(not timer_key_allowed[eos_token_id], "valid arg-key prefix should not fail closed")

tok:close()
print("test_constraints_malformed.lua: ok")
