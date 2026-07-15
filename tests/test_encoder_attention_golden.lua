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
  local pattern = '"' .. key .. '"%s*:%s*([-+%d%.eE]+)'
  local value = text:match(pattern)
  assert(value, "missing numeric field: " .. key)
  return tonumber(value)
end

local function array_field(text, key)
  local pattern = '"' .. key .. '"%s*:%s*%[(.-)%]'
  local body = text:match(pattern)
  assert(body, "missing array field: " .. key)
  local out = {}
  for number in body:gmatch("[-+]?%d+%.?%d*[eE]?[-+]?%d*") do
    out[#out + 1] = tonumber(number)
  end
  return out
end

local golden = read_file(golden_path)
local seq_len = number_field(golden, "seq_len")
local layer = number_field(golden, "layer")
local input = array_field(golden, "input")
local expected = array_field(golden, "expected")
local expected_decoder_self = array_field(golden, "expected_decoder_self")
local cross_encoder = array_field(golden, "cross_encoder")
local expected_decoder_cross = array_field(golden, "expected_decoder_cross")
local expected_decoder_block = array_field(golden, "expected_decoder_block")
local expected_block = array_field(golden, "expected_block")
local encoder_tokens = array_field(golden, "encoder_tokens")
local expected_encoder = array_field(golden, "expected_encoder")
local decoder_tokens = array_field(golden, "decoder_tokens")
local expected_decoder = array_field(golden, "expected_decoder")
local expected_forward_logits = array_field(golden, "expected_forward_logits")
local generation_src = array_field(golden, "generation_src")
local generation_prompt = array_field(golden, "generation_prompt")
local expected_generation = array_field(golden, "expected_generation")
local tolerance = number_field(golden, "tolerance")

local ctx, err = needle.load(model_path)
assert(ctx ~= nil, "loader returned nil")
assert(err == nil or err.code == needle.errors.OK, err and err.message or "load failed")
local cfg = assert(ctx:config())
local d_model = cfg.d_model

local actual, attn_err = ctx:encoder_self_attention(layer, input, seq_len)
assert(actual ~= nil, attn_err and attn_err.message or "encoder attention failed")
assert(#actual == #expected, "golden length mismatch")

for i = 1, #expected do
  local diff = math.abs(actual[i] - expected[i])
  assert(diff <= tolerance, ("golden mismatch at %d: %.9g vs %.9g diff %.9g"):format(i, actual[i], expected[i], diff))
end

local decoder_self, dec_err = ctx:decoder_self_attention(layer, input, seq_len)
assert(decoder_self ~= nil, dec_err and dec_err.message or "decoder self-attention failed")
assert(#decoder_self == #expected_decoder_self, "decoder self-attention golden length mismatch")
for i = 1, #expected_decoder_self do
  local diff = math.abs(decoder_self[i] - expected_decoder_self[i])
  assert(diff <= tolerance, ("decoder self-attention golden mismatch at %d: %.9g vs %.9g diff %.9g"):format(i, decoder_self[i], expected_decoder_self[i], diff))
end

local decoder_cross, cross_err = ctx:decoder_cross_attention(layer, input, seq_len, cross_encoder, seq_len)
assert(decoder_cross ~= nil, cross_err and cross_err.message or "decoder cross-attention failed")
assert(#decoder_cross == #expected_decoder_cross, "decoder cross-attention golden length mismatch")
for i = 1, #expected_decoder_cross do
  local diff = math.abs(decoder_cross[i] - expected_decoder_cross[i])
  assert(diff <= tolerance, ("decoder cross-attention golden mismatch at %d: %.9g vs %.9g diff %.9g"):format(i, decoder_cross[i], expected_decoder_cross[i], diff))
end

local decoder_block, dec_block_err = ctx:decoder_block(layer, input, seq_len, cross_encoder, seq_len)
assert(decoder_block ~= nil, dec_block_err and dec_block_err.message or "decoder block failed")
assert(#decoder_block == #expected_decoder_block, "decoder block golden length mismatch")
for i = 1, #expected_decoder_block do
  local diff = math.abs(decoder_block[i] - expected_decoder_block[i])
  assert(diff <= tolerance, ("decoder block golden mismatch at %d: %.9g vs %.9g diff %.9g"):format(i, decoder_block[i], expected_decoder_block[i], diff))
end

local block_cache = assert(ctx:create_kv_cache(seq_len))
local cached_decoder_block = {}
for t = 1, seq_len do
  local row = {}
  for d = 1, d_model do
    row[d] = input[(t - 1) * d_model + d]
  end
  local step = assert(ctx:decoder_block_cached_step(block_cache, layer, row, cross_encoder, seq_len))
  for d = 1, d_model do
    cached_decoder_block[#cached_decoder_block + 1] = step[d]
  end
end
assert(block_cache:info().token_count == seq_len, "cached decoder block token count mismatch")
block_cache:close()
for i = 1, #decoder_block do
  local diff = math.abs(cached_decoder_block[i] - decoder_block[i])
  assert(diff <= tolerance, ("cached decoder block mismatch at %d: %.9g vs %.9g diff %.9g"):format(i, cached_decoder_block[i], decoder_block[i], diff))
end

local block, block_err = ctx:encoder_block(layer, input, seq_len)
assert(block ~= nil, block_err and block_err.message or "encoder block failed")
assert(#block == #expected_block, "block golden length mismatch")
for i = 1, #expected_block do
  local diff = math.abs(block[i] - expected_block[i])
  assert(diff <= tolerance, ("block golden mismatch at %d: %.9g vs %.9g diff %.9g"):format(i, block[i], expected_block[i], diff))
end

local encoder, enc_err = ctx:encode_tokens(encoder_tokens)
assert(encoder ~= nil, enc_err and enc_err.message or "encoder failed")
assert(#encoder == #expected_encoder, "encoder golden length mismatch")
for i = 1, #expected_encoder do
  local diff = math.abs(encoder[i] - expected_encoder[i])
  assert(diff <= tolerance, ("encoder golden mismatch at %d: %.9g vs %.9g diff %.9g"):format(i, encoder[i], expected_encoder[i], diff))
end

local decoder, decoder_err = ctx:decode_tokens(decoder_tokens, cross_encoder, seq_len)
assert(decoder ~= nil, decoder_err and decoder_err.message or "decoder failed")
assert(#decoder == #expected_decoder, "decoder golden length mismatch")
for i = 1, #expected_decoder do
  local diff = math.abs(decoder[i] - expected_decoder[i])
  assert(diff <= tolerance, ("decoder golden mismatch at %d: %.9g vs %.9g diff %.9g"):format(i, decoder[i], expected_decoder[i], diff))
end

local decode_cache = assert(ctx:create_kv_cache(#decoder_tokens))
local cached_decoder = {}
for i = 1, #decoder_tokens do
  local step = assert(ctx:decode_token_cached_step(decode_cache, decoder_tokens[i], cross_encoder, seq_len))
  for d = 1, d_model do
    cached_decoder[#cached_decoder + 1] = step[d]
  end
end
assert(decode_cache:info().token_count == #decoder_tokens, "cached decoder token count mismatch")
decode_cache:close()
for i = 1, #decoder do
  local diff = math.abs(cached_decoder[i] - decoder[i])
  assert(diff <= tolerance, ("cached decoder mismatch at %d: %.9g vs %.9g diff %.9g"):format(i, cached_decoder[i], decoder[i], diff))
end

local forward_logits, fwd_err = ctx:forward_logits(encoder_tokens, decoder_tokens)
assert(forward_logits ~= nil, fwd_err and fwd_err.message or "forward failed")
assert(#forward_logits == #expected_forward_logits, "forward logits golden length mismatch")
for i = 1, #expected_forward_logits do
  local diff = math.abs(forward_logits[i] - expected_forward_logits[i])
  assert(diff <= tolerance, ("forward logits golden mismatch at %d: %.9g vs %.9g diff %.9g"):format(i, forward_logits[i], expected_forward_logits[i], diff))
end

local generated, gen_err = ctx:generate_tokens(generation_src, generation_prompt, {
  max_new_tokens = #expected_generation - #generation_prompt,
  eos_token_id = -1,
})
assert(generated ~= nil, gen_err and gen_err.message or "generation failed")
assert(#generated == #expected_generation, "generation length mismatch")
for i = 1, #expected_generation do
  assert(generated[i] == expected_generation[i], ("generation mismatch at %d: %s vs %s"):format(i, tostring(generated[i]), tostring(expected_generation[i])))
end

local cached_generated, cached_gen_err = ctx:generate_tokens(generation_src, generation_prompt, {
  max_new_tokens = #expected_generation - #generation_prompt,
  eos_token_id = -1,
  use_cache = true,
})
assert(cached_generated ~= nil, cached_gen_err and cached_gen_err.message or "cached generation failed")
assert(#cached_generated == #generated, "cached generation length mismatch")
for i = 1, #generated do
  assert(cached_generated[i] == generated[i], ("cached generation mismatch at %d: %s vs %s"):format(i, tostring(cached_generated[i]), tostring(generated[i])))
end

local constrained, constrained_err = ctx:generate_tokens(generation_src, generation_prompt, {
  max_new_tokens = 3,
  eos_token_id = -1,
  allowed_token_ids_by_step = {
    { 1 },
    { 0 },
    { 1 },
  },
})
assert(constrained ~= nil, constrained_err and constrained_err.message or "constrained generation failed")
assert(#constrained == 4, "constrained generation length mismatch")
assert(constrained[1] == generation_prompt[1], "constrained generation prompt mismatch")
assert(constrained[2] == 1 and constrained[3] == 0 and constrained[4] == 1, "allowed_token_ids_by_step was not enforced")

local cached_constrained, cached_constrained_err = ctx:generate_tokens(generation_src, generation_prompt, {
  max_new_tokens = 3,
  eos_token_id = -1,
  use_cache = true,
  allowed_token_ids_by_step = {
    { 1 },
    { 0 },
    { 1 },
  },
})
assert(cached_constrained ~= nil, cached_constrained_err and cached_constrained_err.message or "cached constrained generation failed")
for i = 1, #constrained do
  assert(cached_constrained[i] == constrained[i], ("cached constrained generation mismatch at %d"):format(i))
end

local callback_constrained, callback_err = ctx:generate_tokens(generation_src, generation_prompt, {
  max_new_tokens = 2,
  eos_token_id = -1,
  token_filter = function(step, tokens, logits, vocab_size)
    assert(vocab_size == 2, "filter vocab size mismatch")
    assert(#tokens == step, "filter token history mismatch")
    assert(logits[0] ~= nil and logits[1] ~= nil, "filter logits unavailable")
    if step == 1 then
      return { 1 }
    end
    return { 0 }
  end,
})
assert(callback_constrained ~= nil, callback_err and callback_err.message or "callback constrained generation failed")
assert(callback_constrained[2] == 1 and callback_constrained[3] == 0, "token_filter was not enforced")

local raw_callback_constrained, raw_callback_err = ctx:generate_tokens(generation_src, generation_prompt, {
  max_new_tokens = 2,
  eos_token_id = -1,
  token_filter_raw = function(step, tokens, token_count, logits, vocab_size)
    assert(vocab_size == 2, "raw filter vocab size mismatch")
    assert(token_count == step, "raw filter token history mismatch")
    assert(tonumber(tokens[0]) == generation_prompt[1], "raw filter prompt token mismatch")
    assert(logits[0] ~= nil and logits[1] ~= nil, "raw filter logits unavailable")
    if step == 1 then
      return { 1 }
    end
    assert(tonumber(tokens[1]) == 1, "raw filter generated token mismatch")
    return { 0 }
  end,
})
assert(raw_callback_constrained ~= nil, raw_callback_err and raw_callback_err.message or "raw callback constrained generation failed")
assert(raw_callback_constrained[2] == 1 and raw_callback_constrained[3] == 0, "token_filter_raw was not enforced")

local stream_state = assert(ctx:encode_tokens_state(generation_src))
local streamed = {}
local stream_generated, stream_err = ctx:generate_tokens_from_state(stream_state, generation_prompt, {
  max_new_tokens = 2,
  eos_token_id = -1,
  token_filter_raw = function(step)
    if step == 1 then
      return { 1 }
    end
    return { 0 }
  end,
  on_token = function(token_id, step, _, token_count)
    streamed[#streamed + 1] = token_id
    assert(step == #streamed, "stream step mismatch")
    assert(token_count == #generation_prompt + #streamed, "stream token count mismatch")
    return true
  end,
})
stream_state:close()
assert(stream_generated ~= nil, stream_err and stream_err.message or "stream generation failed")
assert(streamed[1] == 1 and streamed[2] == 0, "stream token callback mismatch")
assert(stream_generated[2] == streamed[1] and stream_generated[3] == streamed[2], "stream output mismatch")

local fake_tokenizer = {}
function fake_tokenizer:encode(text)
  if text == "q" then return { 0 } end
  if text == "tools" then return { 1 } end
  return { 0 }
end
function fake_tokenizer:decode(ids)
  local parts = {}
  for i = 1, #ids do parts[#parts + 1] = tostring(ids[i]) end
  return table.concat(parts, ",")
end

local text, text_err, _, text_tokens, text_src = ctx:generate("q", "tools", {
  tokenizer = fake_tokenizer,
  tools_token_id = 0,
  prompt_ids = { 0 },
  eos_token_id = -1,
  max_new_tokens = 2,
  return_tokens = true,
})
assert(text ~= nil, text_err and text_err.message or "string generation failed")
assert(#text_tokens == 3, "string generation token length mismatch")
assert(#text_src == 3 and text_src[1] == 0 and text_src[2] == 0 and text_src[3] == 1, "encoder input assembly mismatch")
assert(text == tostring(text_tokens[2]) .. "," .. tostring(text_tokens[3]), "decoded string generation mismatch")

ctx:close()
print("test_encoder_attention_golden.lua: ok")
