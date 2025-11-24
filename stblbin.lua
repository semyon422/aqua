local ffi = require("ffi")
local byte = require("byte")

local stblbin = {}

---@alias stblbin.Type "number"|"string"|"boolean"|"table"
---@alias stblbin.Key number|string
---@alias stblbin.Value number|string|boolean|stblbin.Table
---@alias stblbin.Table {[stblbin.Key]: stblbin.Value}

--[[
	enum type:
		number = 0
		string = 1
		boolean = 2
		table = 3

	struct Number
		uint8 type
		double value

	struct String
		uint8 type
		uint16 size
		char[size] value

	struct Boolean
		uint8 type
		uint8 value

	struct Table
		uint8 type
		uint32 size
		{Key key, Value value}[size]
]]

---@param k any
---@return stblbin.Key
local function assert_key_type(k)
	local t = type(k)
	if
		t == "number" or
		t == "string"
	then
		return k
	end
	error(("unsupported key type '%s'"):format(t))
end

---@param v any
---@return stblbin.Type
local function value_type(v)
	local t = type(v)
	if
		t == "number" or
		t == "string" or
		t == "boolean" or
		t == "table"
	then
		---@cast t stblbin.Type
		return t
	end
	error(("unsupported value type '%s'"):format(t))
end

---@param a stblbin.Key
---@param b stblbin.Key
---@return boolean
local function compare_keys(a, b)
	local ta = type(a)
	if ta == type(b) then
		return a < b
	end
	return ta == "number"
end

---@param tbl stblbin.Table
---@return stblbin.Key[]
local function sorted_keys(tbl)
	local keys = {}
	for k in pairs(tbl) do
		assert_key_type(k)
		table.insert(keys, k)
	end
	table.sort(keys, compare_keys)
	return keys
end

---@type {[stblbin.Type]: integer}
local type_enum = {
	number = 0,
	string = 1,
	boolean = 2,
	table = 3,
}

---@type {[integer]: stblbin.Type}
local type_enum_inv = {}

for k, v in pairs(type_enum) do
	type_enum_inv[v] = k
end

local u = byte.yield_union()

---@type {[stblbin.Type]: fun(v: stblbin.Value)}
local encoders = {}

---@type {[stblbin.Type]: fun(): stblbin.Value}
local decoders = {}

---@param v boolean
function encoders.boolean(v)
	u.i8 = v and 1 or 0
end

---@return boolean
function decoders.boolean()
	return u.i8 ~= 0
end

---@param v number
function encoders.number(v)
	u.f64 = v
end

---@return number
function decoders.number()
	return u.f64
end

---@param v string
---@return integer
function encoders.string(v)
	u.u16 = #v
	u.char = v
end

---@return string
function decoders.string()
	local size = u.i16
	return u:string(size)
end

---@param tbl table
function encoders.table(tbl)
	local keys = sorted_keys(tbl)
	u.u32 = #keys
	for _, k in ipairs(keys) do
		stblbin.encode_async(k)
		stblbin.encode_async(tbl[k])
	end
end

---@return stblbin.Table
function decoders.table()
	local count = u.u32
	---@type {[stblbin.Key]: stblbin.Value}
	local tbl = {}
	for _ = 1, count do
		local k = stblbin.decode_async()
		local v = stblbin.decode_async()
		tbl[assert_key_type(k)] = v
	end
	return tbl
end

---@return stblbin.Value
function stblbin.decode_async()
	local t = type_enum_inv[u.u8]
	return decoders[t]()
end

---@param v stblbin.Value
function stblbin.encode_async(v)
	local t = value_type(v)
	u.u8 = type_enum[t]
	encoders[t](v)
end

---@param p ffi.cdata*
---@param size integer
---@return stblbin.Value
---@return integer size total read size
function stblbin.decode(p, size)
	local ok, bytes, value = byte.apply(byte.seeker(p, size), stblbin.decode_async)
	assert(ok, "invalid data")
	return value, bytes
end

---@param p ffi.cdata*
---@param size integer
---@param obj stblbin.Value
---@return integer size total write size
function stblbin.encode(p, size, obj)
	local ok, bytes = byte.apply(byte.seeker(p, size), stblbin.encode_async, obj)
	assert(ok, "invalid data")
	return bytes
end

---@param s string
---@return stblbin.Value
function stblbin.decode_s(s)
	return (stblbin.decode(ffi.cast("const char *", s), #s))
end

---@param obj stblbin.Value
---@param max_size integer
---@return string?
function stblbin.encode_s(obj, max_size)
	local buf = byte.buffer(8192)
	local f = byte.stretchy_seeker(buf, max_size)

	local ok, bytes = byte.apply(f, stblbin.encode_async, obj)
	if not ok then
		buf:free()
		return
	end

	local s = ffi.string(buf.ptr, bytes)
	buf:free()

	return s
end

-- tests

local p = ffi.new("uint8_t[?]", 1e4)

local t = {
	a = 1,
	b = "hi",
	c = true,
	d = {
		q = {1, 2},
		1,
		2,
	},
	10,
	20,
}


local buf = byte.buffer(1e4) -- manual encode
buf:write("u8", type_enum.table)
do
	buf:write("u32", 6)
	buf:write("u8", type_enum.number)
	buf:write("f64", 1)
	buf:write("u8", type_enum.number)
	buf:write("f64", 10)
	buf:write("u8", type_enum.number)
	buf:write("f64", 2)
	buf:write("u8", type_enum.number)
	buf:write("f64", 20)
	buf:write("u8", type_enum.string)
	buf:write("u16", 1)
	buf:fill("a")
	buf:write("u8", type_enum.number)
	buf:write("f64", 1)
	buf:write("u8", type_enum.string)
	buf:write("u16", 1)
	buf:fill("b")
	buf:write("u8", type_enum.string)
	buf:write("u16", 2)
	buf:fill("hi")
	buf:write("u8", type_enum.string)
	buf:write("u16", 1)
	buf:fill("c")
	buf:write("u8", type_enum.boolean)
	buf:write("u8", 1)
	buf:write("u8", type_enum.string)
	buf:write("u16", 1)
	buf:fill("d")
	buf:write("u8", type_enum.table)
	do
		buf:write("u32", 3)
		buf:write("u8", type_enum.number)
		buf:write("f64", 1)
		buf:write("u8", type_enum.number)
		buf:write("f64", 1)
		buf:write("u8", type_enum.number)
		buf:write("f64", 2)
		buf:write("u8", type_enum.number)
		buf:write("f64", 2)
		buf:write("u8", type_enum.string)
		buf:write("u16", 1)
		buf:fill("q")
		buf:write("u8", type_enum.table)
		do
			buf:write("u32", 2)
			buf:write("u8", type_enum.number)
			buf:write("f64", 1)
			buf:write("u8", type_enum.number)
			buf:write("f64", 1)
			buf:write("u8", type_enum.number)
			buf:write("f64", 2)
			buf:write("u8", type_enum.number)
			buf:write("f64", 2)
		end
	end
end

local buf_size = assert(tonumber(buf.offset))
buf:seek(0)
local buf_str = buf:string(buf_size)

local size_encoded = stblbin.encode(p, buf_size, t)
assert(size_encoded == buf_size)

local ptr_str = ffi.string(p, size_encoded)

assert(#buf_str == #ptr_str)
assert(buf_str == ptr_str)
assert(buf_str == stblbin.encode_s(t, 1000))
assert(buf_str == stblbin.encode_s(stblbin.decode_s(buf_str), 1000))

local _t = stblbin.decode(p, buf_size)
---@cast _t stblbin.Table

local table_util = require("table_util")
assert(table_util.deepequal(t, _t))

return stblbin
