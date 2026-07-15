local needle = require("needle")

local fixture = arg[1]
assert(fixture and fixture ~= "", "fixture path required")

local function read_file(path)
  local f = assert(io.open(path, "rb"))
  local data = assert(f:read("*a"))
  f:close()
  return data
end

local function write_file(path, data)
  local f = assert(io.open(path, "wb"))
  assert(f:write(data))
  f:close()
end

local function le16(data, pos)
  local b1, b2 = data:byte(pos, pos + 1)
  return b1 + b2 * 256
end

local function le32(data, pos)
  local b1, b2, b3, b4 = data:byte(pos, pos + 3)
  return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

local function le64_small(data, pos)
  local lo = le32(data, pos)
  local hi = le32(data, pos + 4)
  assert(hi == 0, "test fixture value exceeds exact small integer range")
  return lo
end

local function replace_bytes(data, pos, bytes)
  return data:sub(1, pos - 1) .. bytes .. data:sub(pos + #bytes)
end

local function expect_load_error(path, code, message_pattern)
  local ctx, err = needle.load(path)
  assert(ctx ~= nil, "loader should return a context for structured errors")
  assert(err and err.code == code, "unexpected error code for " .. path)
  assert(err.message:match(message_pattern), "unexpected error message: " .. tostring(err.message))
  assert(not ctx:is_loaded(), "invalid fixture should not be marked loaded")
  ctx:close()
end

local data = read_file(fixture)
local prefix = fixture .. ".bad"
local temp_paths = {}

local function write_bad(suffix, bytes)
  local path = prefix .. suffix
  temp_paths[#temp_paths + 1] = path
  write_file(path, bytes)
  return path
end

expect_load_error(write_bad(".magic", "BADMAGIC"), needle.errors.FORMAT, "invalid runtime model magic")

expect_load_error(write_bad(".header", data:sub(1, 20)), needle.errors.FORMAT, "truncated runtime model header")

expect_load_error(
  write_bad(".version", replace_bytes(data, 9, string.char(2, 0, 0, 0))),
  needle.errors.UNSUPPORTED,
  "unsupported runtime format version 2"
)

expect_load_error(write_bad(".trailing", data .. "x"), needle.errors.FORMAT, "unexpected trailing bytes")

local metadata_len = le64_small(data, 17)
local tokenizer_len = le64_small(data, 25)
local tensor_table = 41 + metadata_len + tokenizer_len
assert(le16(data, tensor_table) > 0, "expected first tensor name")
local dtype_pos = tensor_table + 2
expect_load_error(
  write_bad(".dtype", replace_bytes(data, dtype_pos, string.char(99, 0))),
  needle.errors.FORMAT,
  "invalid tensor dtype"
)

for _, path in ipairs(temp_paths) do
  os.remove(path)
end

print("test_loader_errors.lua: ok")
