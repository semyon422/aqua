local needle = require("needle")

local model_path = arg[1]
local golden_path = arg[2]
assert(model_path and model_path ~= "", "model path required")
assert(golden_path and golden_path ~= "", "golden path required")

local function read_file(path)
  local f = assert(io.open(path, "rb"))
  local data = assert(f:read("*a"))
  f:close()
  return data
end

local function number_field(text, key)
  local value = text:match('"' .. key .. '"%s*:%s*([-+%d%.eE]+)')
  assert(value, "missing numeric field: " .. key)
  return tonumber(value)
end

local function array_field(text, key)
  local body = text:match('"' .. key .. '"%s*:%s*%[(.-)%]')
  assert(body, "missing array field: " .. key)
  local out = {}
  for number in body:gmatch("[-+]?%d+%.?%d*[eE]?[-+]?%d*") do
    out[#out + 1] = tonumber(number)
  end
  return out
end

local function string_field(text, key)
  local value = text:match('"' .. key .. '"%s*:%s*"(.-)"')
  assert(value ~= nil, "missing string field: " .. key)
  return value:gsub('\\"', '"')
end

local golden = read_file(golden_path)
local seq_len = number_field(golden, "seq_len")
local layer = number_field(golden, "layer")
local input = array_field(golden, "input")
local expected = array_field(golden, "expected")
local expected_decoder_self = array_field(golden, "expected_decoder_self")
local expected_decoder_cross = array_field(golden, "expected_decoder_cross")
local expected_decoder_block = array_field(golden, "expected_decoder_block")
local expected_decoder = array_field(golden, "expected_decoder")
local expected_forward_logits = array_field(golden, "expected_forward_logits")
local expected_generation_ids = array_field(golden, "expected_generation_ids")
local expected_block = array_field(golden, "expected_block")
local expected_logits = array_field(golden, "expected_logits")
local expected_encoder = array_field(golden, "expected_encoder")
local tolerance = number_field(golden, "tolerance")
local logit_tolerance = number_field(golden, "logit_tolerance")
local cross_tolerance = number_field(golden, "cross_tolerance")
local generation_query = string_field(golden, "generation_query")
local generation_tools = string_field(golden, "generation_tools")
local generation_max_new = number_field(golden, "generation_max_new")

local ctx, err = needle.load(model_path)
assert(ctx ~= nil, "loader returned nil")
assert(err == nil or err.code == needle.errors.OK, err and err.message or "load failed")

local actual, attn_err = ctx:encoder_self_attention(layer, input, seq_len)
assert(actual ~= nil, attn_err and attn_err.message or "encoder attention failed")
assert(#actual == #expected, "real golden length mismatch")

local max_diff = 0
local max_i = 0
for i = 1, #expected do
  local diff = math.abs(actual[i] - expected[i])
  if diff > max_diff then
    max_diff = diff
    max_i = i
  end
end

assert(max_diff <= tolerance, ("real golden max diff %.9g at %d exceeds %.9g: %.9g vs %.9g"):format(
  max_diff, max_i, tolerance, actual[max_i], expected[max_i]
))

local decoder_self, dec_err = ctx:decoder_self_attention(layer, input, seq_len)
assert(decoder_self ~= nil, dec_err and dec_err.message or "decoder self-attention failed")
assert(#decoder_self == #expected_decoder_self, "real decoder self-attention golden length mismatch")

local dec_max_diff = 0
local dec_max_i = 0
for i = 1, #expected_decoder_self do
  local diff = math.abs(decoder_self[i] - expected_decoder_self[i])
  if diff > dec_max_diff then
    dec_max_diff = diff
    dec_max_i = i
  end
end
assert(dec_max_diff <= tolerance, ("real decoder self-attention max diff %.9g at %d exceeds %.9g: %.9g vs %.9g"):format(
  dec_max_diff, dec_max_i, tolerance, decoder_self[dec_max_i], expected_decoder_self[dec_max_i]
))

local cfg = assert(ctx:config())
local cache = assert(ctx:create_kv_cache(seq_len))
local cached_decoder_self = {}
for t = 1, seq_len do
  local row = {}
  for d = 1, cfg.d_model do
    row[d] = input[(t - 1) * cfg.d_model + d]
  end
  local step = assert(ctx:decoder_self_attention_cached_step(cache, layer, row))
  assert(#step == cfg.d_model, "real cached decoder self-attention step length mismatch")
  for d = 1, cfg.d_model do
    cached_decoder_self[#cached_decoder_self + 1] = step[d]
  end
end
assert(cache:info().token_count == seq_len, "real KV cache token count mismatch")
cache:close()

local cached_dec_max_diff = 0
local cached_dec_max_i = 1
for i = 1, #decoder_self do
  local diff = math.abs(cached_decoder_self[i] - decoder_self[i])
  if diff > cached_dec_max_diff then
    cached_dec_max_diff = diff
    cached_dec_max_i = i
  end
end
assert(cached_dec_max_diff <= tolerance, ("real cached decoder self-attention max diff %.9g at %d exceeds %.9g: %.9g vs %.9g"):format(
  cached_dec_max_diff, cached_dec_max_i, tolerance, cached_decoder_self[cached_dec_max_i], decoder_self[cached_dec_max_i]
))

local block, block_err = ctx:encoder_block(layer, input, seq_len)
assert(block ~= nil, block_err and block_err.message or "encoder block failed")
assert(#block == #expected_block, "real block golden length mismatch")

local block_max_diff = 0
local block_max_i = 0
for i = 1, #expected_block do
  local diff = math.abs(block[i] - expected_block[i])
  if diff > block_max_diff then
    block_max_diff = diff
    block_max_i = i
  end
end

assert(block_max_diff <= tolerance, ("real block golden max diff %.9g at %d exceeds %.9g: %.9g vs %.9g"):format(
  block_max_diff, block_max_i, tolerance, block[block_max_i], expected_block[block_max_i]
))

local logits, logits_err = ctx:output_projection(block, seq_len)
assert(logits ~= nil, logits_err and logits_err.message or "output projection failed")
assert(#logits == #expected_logits, "real logits golden length mismatch")

local logits_max_diff = 0
local logits_max_i = 0
for i = 1, #expected_logits do
  local diff = math.abs(logits[i] - expected_logits[i])
  if diff > logits_max_diff then
    logits_max_diff = diff
    logits_max_i = i
  end
end

assert(logits_max_diff <= logit_tolerance, ("real logits golden max diff %.9g at %d exceeds %.9g: %.9g vs %.9g"):format(
  logits_max_diff, logits_max_i, logit_tolerance, logits[logits_max_i], expected_logits[logits_max_i]
))

local tokens = array_field(golden, "tokens")
local encoder, encoder_err = ctx:encode_tokens(tokens)
assert(encoder ~= nil, encoder_err and encoder_err.message or "encoder failed")
assert(#encoder == #expected_encoder, "real encoder golden length mismatch")

local encoder_max_diff = 0
local encoder_max_i = 0
for i = 1, #expected_encoder do
  local diff = math.abs(encoder[i] - expected_encoder[i])
  if diff > encoder_max_diff then
    encoder_max_diff = diff
    encoder_max_i = i
  end
end

assert(encoder_max_diff <= tolerance, ("real encoder golden max diff %.9g at %d exceeds %.9g: %.9g vs %.9g"):format(
  encoder_max_diff, encoder_max_i, tolerance, encoder[encoder_max_i], expected_encoder[encoder_max_i]
))

local decoder_cross, cross_err = ctx:decoder_cross_attention(layer, input, seq_len, encoder, seq_len)
assert(decoder_cross ~= nil, cross_err and cross_err.message or "decoder cross-attention failed")
assert(#decoder_cross == #expected_decoder_cross, "real decoder cross-attention golden length mismatch")

local cross_max_diff = 0
local cross_max_i = 0
for i = 1, #expected_decoder_cross do
  local diff = math.abs(decoder_cross[i] - expected_decoder_cross[i])
  if diff > cross_max_diff then
    cross_max_diff = diff
    cross_max_i = i
  end
end
assert(cross_max_diff <= cross_tolerance, ("real decoder cross-attention max diff %.9g at %d exceeds %.9g: %.9g vs %.9g"):format(
  cross_max_diff, cross_max_i, cross_tolerance, decoder_cross[cross_max_i], expected_decoder_cross[cross_max_i]
))

local decoder_block, dec_block_err = ctx:decoder_block(layer, input, seq_len, encoder, seq_len)
assert(decoder_block ~= nil, dec_block_err and dec_block_err.message or "decoder block failed")
assert(#decoder_block == #expected_decoder_block, "real decoder block golden length mismatch")

local dec_block_max_diff = 0
local dec_block_max_i = 0
for i = 1, #expected_decoder_block do
  local diff = math.abs(decoder_block[i] - expected_decoder_block[i])
  if diff > dec_block_max_diff then
    dec_block_max_diff = diff
    dec_block_max_i = i
  end
end
assert(dec_block_max_diff <= cross_tolerance, ("real decoder block max diff %.9g at %d exceeds %.9g: %.9g vs %.9g"):format(
  dec_block_max_diff, dec_block_max_i, cross_tolerance, decoder_block[dec_block_max_i], expected_decoder_block[dec_block_max_i]
))

local block_cache = assert(ctx:create_kv_cache(seq_len))
local cached_decoder_block = {}
for t = 1, seq_len do
  local row = {}
  for d = 1, cfg.d_model do
    row[d] = input[(t - 1) * cfg.d_model + d]
  end
  local step = assert(ctx:decoder_block_cached_step(block_cache, layer, row, encoder, seq_len))
  assert(#step == cfg.d_model, "real cached decoder block step length mismatch")
  for d = 1, cfg.d_model do
    cached_decoder_block[#cached_decoder_block + 1] = step[d]
  end
end
assert(block_cache:info().token_count == seq_len, "real decoder block KV cache token count mismatch")
block_cache:close()

local cached_block_max_diff = 0
local cached_block_max_i = 1
for i = 1, #decoder_block do
  local diff = math.abs(cached_decoder_block[i] - decoder_block[i])
  if diff > cached_block_max_diff then
    cached_block_max_diff = diff
    cached_block_max_i = i
  end
end
assert(cached_block_max_diff <= cross_tolerance, ("real cached decoder block max diff %.9g at %d exceeds %.9g: %.9g vs %.9g"):format(
  cached_block_max_diff, cached_block_max_i, cross_tolerance, cached_decoder_block[cached_block_max_i], decoder_block[cached_block_max_i]
))

local decoder, decoder_err = ctx:decode_tokens(tokens, encoder, seq_len)
assert(decoder ~= nil, decoder_err and decoder_err.message or "decoder failed")
assert(#decoder == #expected_decoder, "real decoder golden length mismatch")

local decoder_max_diff = 0
local decoder_max_i = 0
for i = 1, #expected_decoder do
  local diff = math.abs(decoder[i] - expected_decoder[i])
  if diff > decoder_max_diff then
    decoder_max_diff = diff
    decoder_max_i = i
  end
end
assert(decoder_max_diff <= cross_tolerance, ("real decoder max diff %.9g at %d exceeds %.9g: %.9g vs %.9g"):format(
  decoder_max_diff, decoder_max_i, cross_tolerance, decoder[decoder_max_i], expected_decoder[decoder_max_i]
))

local decode_cache = assert(ctx:create_kv_cache(seq_len))
local cached_decoder = {}
for i = 1, #tokens do
  local step = assert(ctx:decode_token_cached_step(decode_cache, tokens[i], encoder, seq_len))
  assert(#step == cfg.d_model, "real cached decoder step length mismatch")
  for d = 1, cfg.d_model do
    cached_decoder[#cached_decoder + 1] = step[d]
  end
end
assert(decode_cache:info().token_count == #tokens, "real cached decoder token count mismatch")
decode_cache:close()

local cached_decoder_max_diff = 0
local cached_decoder_max_i = 1
for i = 1, #decoder do
  local diff = math.abs(cached_decoder[i] - decoder[i])
  if diff > cached_decoder_max_diff then
    cached_decoder_max_diff = diff
    cached_decoder_max_i = i
  end
end
assert(cached_decoder_max_diff <= cross_tolerance, ("real cached decoder max diff %.9g at %d exceeds %.9g: %.9g vs %.9g"):format(
  cached_decoder_max_diff, cached_decoder_max_i, cross_tolerance, cached_decoder[cached_decoder_max_i], decoder[cached_decoder_max_i]
))

local forward_logits, fwd_err = ctx:forward_logits(tokens, tokens)
assert(forward_logits ~= nil, fwd_err and fwd_err.message or "forward failed")
assert(#forward_logits == #expected_forward_logits, "real forward logits golden length mismatch")

local forward_max_diff = 0
local forward_max_i = 0
for i = 1, #expected_forward_logits do
  local diff = math.abs(forward_logits[i] - expected_forward_logits[i])
  if diff > forward_max_diff then
    forward_max_diff = diff
    forward_max_i = i
  end
end
assert(forward_max_diff <= logit_tolerance, ("real forward logits max diff %.9g at %d exceeds %.9g: %.9g vs %.9g"):format(
  forward_max_diff, forward_max_i, logit_tolerance, forward_logits[forward_max_i], expected_forward_logits[forward_max_i]
))

local _, gen_err, _, generated_ids = ctx:generate(generation_query, generation_tools, {
  tokenizer_path = "build/tokenizer.ndltok",
  max_new_tokens = generation_max_new,
  return_tokens = true,
})
assert(generated_ids ~= nil, gen_err and gen_err.message or "real generation failed")
assert(#generated_ids == #expected_generation_ids, "real generation length mismatch")
for i = 1, #expected_generation_ids do
  assert(generated_ids[i] == expected_generation_ids[i], ("real generation token mismatch at %d: %s vs %s"):format(
    i, tostring(generated_ids[i]), tostring(expected_generation_ids[i])
  ))
end

local _, cached_gen_err, _, cached_generated_ids = ctx:generate(generation_query, generation_tools, {
  tokenizer_path = "build/tokenizer.ndltok",
  max_new_tokens = generation_max_new,
  return_tokens = true,
  use_cache = true,
})
assert(cached_generated_ids ~= nil, cached_gen_err and cached_gen_err.message or "real cached generation failed")
assert(#cached_generated_ids == #generated_ids, "real cached generation length mismatch")
for i = 1, #generated_ids do
  assert(cached_generated_ids[i] == generated_ids[i], ("real cached generation token mismatch at %d: %s vs %s"):format(
    i, tostring(cached_generated_ids[i]), tostring(generated_ids[i])
  ))
end

local pretty_tools = [[
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
local tool_text, tool_err = ctx:generate("weather in Paris", pretty_tools, {
  tokenizer_path = "build/tokenizer.ndltok",
  max_new_tokens = 32,
  constrained = true,
  use_cache = true,
})
assert(tool_text ~= nil, tool_err and tool_err.message or "pretty tool-call generation failed")
assert(tool_text:match('^%[%{"name":"get_weather"'), "pretty tools should generate a get_weather JSON call")

local stream_chunks = {}
local stream_token_count = 0
local stream_text, stream_err = ctx:generate_stream("weather in Paris", pretty_tools, function(chunk)
  stream_chunks[#stream_chunks + 1] = chunk
  return true
end, {
  tokenizer_path = "build/tokenizer.ndltok",
  max_new_tokens = 32,
  constrained = true,
  use_cache = true,
  on_token = function()
    stream_token_count = stream_token_count + 1
    return true
  end,
})
assert(stream_text ~= nil, stream_err and stream_err.message or "stream generation failed")
assert(stream_text == tool_text, "stream final text mismatch")
assert(table.concat(stream_chunks) == stream_text, "stream chunks should reconstruct final text")
assert(stream_token_count > 0, "stream token callback was not invoked")

local tok = assert(needle.load_tokenizer("build/tokenizer.ndltok"))
local src_ids = ctx:build_encoder_input(tok, "weather in Paris", pretty_tools)
local enc_out = assert(ctx:encode_tokens(src_ids))
local constraints = assert(needle.build_tool_call_constraints(pretty_tools, tok, { eos_token_id = 1 }))
local from_encoder_ids, from_encoder_err = ctx:generate_tokens_from_encoder(enc_out, #src_ids, { 1 }, {
  max_new_tokens = 32,
  eos_token_id = 1,
  token_filter = constraints:token_filter(),
})
assert(from_encoder_ids ~= nil, from_encoder_err and from_encoder_err.message or "from-encoder generation failed")
local encoder_state = assert(ctx:encode_tokens_state(src_ids))
local state_constraints = assert(needle.build_tool_call_constraints(pretty_tools, tok, { eos_token_id = 1 }))
local from_state_ids, from_state_err = ctx:generate_tokens_from_state(encoder_state, { 1 }, {
  max_new_tokens = 32,
  eos_token_id = 1,
  token_filter_raw = state_constraints:token_filter_raw(),
})
assert(from_state_ids ~= nil, from_state_err and from_state_err.message or "from-state generation failed")
encoder_state:close()
local direct_constraints = assert(needle.build_tool_call_constraints(pretty_tools, tok, { eos_token_id = 1 }))
local direct_ids = assert(ctx:generate_tokens(src_ids, { 1 }, {
  max_new_tokens = 32,
  eos_token_id = 1,
  token_filter = direct_constraints:token_filter(),
  use_cache = true,
}))
assert(#from_encoder_ids == #direct_ids, "from-encoder generation length mismatch")
for i = 1, #direct_ids do
  assert(from_encoder_ids[i] == direct_ids[i], ("from-encoder token mismatch at %d: %s vs %s"):format(
    i, tostring(from_encoder_ids[i]), tostring(direct_ids[i])
  ))
  assert(from_state_ids[i] == direct_ids[i], ("from-state token mismatch at %d: %s vs %s"):format(
    i, tostring(from_state_ids[i]), tostring(direct_ids[i])
  ))
end
tok:close()

ctx:close()
print(("test_real_encoder_attention_golden.lua: ok max_diff=%.9g dec_max_diff=%.9g cross_max_diff=%.9g dec_block_max_diff=%.9g decoder_max_diff=%.9g block_max_diff=%.9g logits_max_diff=%.9g forward_max_diff=%.9g encoder_max_diff=%.9g"):format(
  max_diff, dec_max_diff, cross_max_diff, dec_block_max_diff, decoder_max_diff, block_max_diff, logits_max_diff, forward_max_diff, encoder_max_diff
))
