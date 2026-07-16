local ok, needle = pcall(require, "needle")
if not ok then needle = require("ai.needle") end

local model_path = assert(arg[1], "model path required")
local context, err = needle.load(model_path)
assert(context and context:is_loaded(), err and err.message)
local tokenizer, tokenizer_err = context:createTokenizer()
assert(tokenizer, tokenizer_err and tokenizer_err.message)
local ids = assert(tokenizer:encode("play a random chart"))
assert(#ids > 0, "embedded tokenizer produced no tokens")
assert(tokenizer:vocab_size() == context:config().vocab_size, "embedded tokenizer vocabulary mismatch")
tokenizer:close()
context:close()
print("test_embedded_tokenizer.lua: ok")
