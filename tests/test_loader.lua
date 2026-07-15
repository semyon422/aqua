local needle = require("needle")

local fixture = arg[1]
assert(fixture and fixture ~= "", "fixture path required")

local ctx, err = needle.load(fixture)
assert(ctx ~= nil, "loader returned nil")
assert(err == nil or err == "", "loader error: " .. tostring(err))
assert(ctx:is_loaded(), "context should be marked loaded")

local info = ctx:info()
assert(info.loaded == true, "info.loaded mismatch")
assert(info.tensor_count == 28, "tensor count mismatch")
assert(info.tensor_data_bytes == 310, "tensor byte count mismatch")
assert(info.tokenizer_bytes == #"tiny-tokenizer", "tokenizer byte count mismatch")
assert(info.metadata_json:match('"format":"NDLRTM1"'), "metadata JSON missing format marker")
assert(info.metadata_json:match('"tensor_count":28'), "metadata JSON missing tensor count")

local result, gen_err, rc = ctx:generate("hello", "[]")
assert(result == nil, "generation without tokenizer should fail")
assert(rc == needle.errors.INVALID_ARGUMENT, "unexpected generation return code")
assert(gen_err.code == needle.errors.INVALID_ARGUMENT, "unexpected generation error code")
assert(gen_err.name == "INVALID_ARGUMENT", "unexpected generation error name")

local ok, stream_err, stream_rc = ctx:generate_stream("hello", "[]", function(_)
  return true
end)
assert(ok == nil, "streaming generation should still be a stub")
assert(stream_rc == needle.errors.NOT_IMPLEMENTED, "unexpected streaming return code")
assert(stream_err.name == "NOT_IMPLEMENTED", "unexpected streaming error name")

ctx:close()
print("test_loader.lua: ok")
