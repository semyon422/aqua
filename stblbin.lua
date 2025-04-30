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

---@param p ffi.cdata*
---@param n integer
---@return ffi.cdata*
local function ptr_add(p, n)
	return p + n
end

---@param a ffi.cdata*
---@param b ffi.cdata*
---@return integer
local function ptr_sub(a, b)
	return tonumber(a - b) --[[@as integer]]
end

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

---@type {[stblbin.Type]: fun(p: ffi.cdata*, v: stblbin.Value): integer}
local encoders = {}

---@type {[stblbin.Type]: fun(p: ffi.cdata*): stblbin.Value, integer}
local decoders = {}

---@param p ffi.cdata*
---@param v boolean
---@return integer
function encoders.boolean(p, v)
	byte.write_int8(p, v and 1 or 0)
	return 1
end

---@param p ffi.cdata*
---@param v number
---@return integer
function encoders.number(p, v)
	byte.write_double_be(p, v)
	return 8
end

---@param p ffi.cdata*
---@return boolean
---@return integer
function decoders.boolean(p)
	return byte.read_int8(p) == 1, 1
end

---@param p ffi.cdata*
---@return number
---@return integer
function decoders.number(p)
	return byte.read_double_be(p), 8
end

---@param p ffi.cdata*
---@param v string
---@return integer
function encoders.string(p, v)
	byte.write_uint16_be(p, #v)
	ffi.copy(p + 2, v, #v)
	return #v + 2
end

---@param p ffi.cdata*
---@return string
---@return integer
function decoders.string(p)
	local size = byte.read_uint16_be(p)
	return ffi.string(p + 2, size), size + 2
end

---@param p ffi.cdata*
---@param tbl table
---@return integer
function encoders.table(p, tbl)
	local p_0 = p
	local keys = sorted_keys(tbl)
	byte.write_uint32_be(p_0, #keys)
	p = ptr_add(p, 4)
	for _, k in ipairs(keys) do
		local key_size = stblbin.encode(p, k)
		p = ptr_add(p, key_size)
		local value_size = stblbin.encode(p, tbl[k])
		p = ptr_add(p, value_size)
	end
	return ptr_sub(p, p_0)
end

---@param p ffi.cdata*
---@return stblbin.Table
---@return integer
function decoders.table(p)
	local p_0 = p
	local count = byte.read_uint32_be(p)
	p = ptr_add(p, 4)
	---@type {[stblbin.Key]: stblbin.Value}
	local tbl = {}
	for _ = 1, count do
		local k, key_size = stblbin.decode(p)
		p = ptr_add(p, key_size)
		local v, value_size = stblbin.decode(p)
		p = ptr_add(p, value_size)
		tbl[assert_key_type(k)] = v
	end
	return tbl, ptr_sub(p, p_0)
end

---@type {[stblbin.Type]: fun(v: stblbin.Value): integer}}
local sizers = {}

function sizers.boolean() return 1 end
function sizers.number() return 8 end
function sizers.string(s) return 2 + #s end

---@return stblbin.Table
---@return integer
function sizers.table(tbl)
	local size = 4
	for k, v in pairs(tbl) do
		size = size + stblbin.size(k) + stblbin.size(v)
	end
	return size
end

---@type {[stblbin.Type|"bound"]: function}
local bounders = {}

function bounders.boolean() coroutine.yield(1) end
function bounders.number() coroutine.yield(8) end

function bounders.string()
	local p = coroutine.yield(2)
	local size = byte.read_uint16_be(p)
	coroutine.yield(size)
end

function bounders.table()
	local p = coroutine.yield(4)
	local count = byte.read_uint32_be(p)
	for _ = 1, count do
		bounders.bound()
		bounders.bound()
	end
end

function bounders.bound()
	local p = coroutine.yield(1)
	local _type = type_enum_inv[byte.read_uint8(p)]
	bounders[_type](p)
end

---@param p ffi.cdata*
---@return stblbin.Value
---@return integer size total read size
function stblbin.decode(p)
	local _type = type_enum_inv[byte.read_uint8(p)]
	local decode = decoders[_type]
	local obj, size = decode(p + 1)
	return obj, 1 + size
end

---@param p ffi.cdata*
---@param obj stblbin.Value
---@return integer size total write size
function stblbin.encode(p, obj)
	local _type = value_type(obj)
	byte.write_uint8(p, type_enum[_type])
	local encode = encoders[_type]
	local size = encode(p + 1, obj)
	return 1 + size
end

---@param obj stblbin.Value
---@return integer
function stblbin.size(obj)
	local _type = value_type(obj)
	local sizer = sizers[_type]
	local size = sizer(obj)
	return size + 1
end

---@param p ffi.cdata*
---@param size integer
---@return integer?
function stblbin.bound(p, size)
	local offset, ps = 0, 0
	local bound = coroutine.wrap(bounders.bound)
	while true do
		---@type integer?
		local s = bound(p + offset - ps)
		if not s then
			return offset
		end
		if offset + s > size then
			return
		end
		offset, ps = offset + s, s
	end
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
buf:uint8(type_enum.table)
do
	buf:uint32_be(6) -- size
	buf:uint8(type_enum.number)
	buf:double_be(1)
	buf:uint8(type_enum.number)
	buf:double_be(10)
	buf:uint8(type_enum.number)
	buf:double_be(2)
	buf:uint8(type_enum.number)
	buf:double_be(20)
	buf:uint8(type_enum.string)
	buf:uint16_be(1)
	buf:fill("a")
	buf:uint8(type_enum.number)
	buf:double_be(1)
	buf:uint8(type_enum.string)
	buf:uint16_be(1)
	buf:fill("b")
	buf:uint8(type_enum.string)
	buf:uint16_be(2)
	buf:fill("hi")
	buf:uint8(type_enum.string)
	buf:uint16_be(1)
	buf:fill("c")
	buf:uint8(type_enum.boolean)
	buf:uint8(1)
	buf:uint8(type_enum.string)
	buf:uint16_be(1)
	buf:fill("d")
	buf:uint8(type_enum.table)
	do
		buf:uint32_be(3)
		buf:uint8(type_enum.number)
		buf:double_be(1)
		buf:uint8(type_enum.number)
		buf:double_be(1)
		buf:uint8(type_enum.number)
		buf:double_be(2)
		buf:uint8(type_enum.number)
		buf:double_be(2)
		buf:uint8(type_enum.string)
		buf:uint16_be(1)
		buf:fill("q")
		buf:uint8(type_enum.table)
		do
			buf:uint32_be(2)
			buf:uint8(type_enum.number)
			buf:double_be(1)
			buf:uint8(type_enum.number)
			buf:double_be(1)
			buf:uint8(type_enum.number)
			buf:double_be(2)
			buf:uint8(type_enum.number)
			buf:double_be(2)
		end
	end
end

local buf_size = tonumber(buf.offset)
buf:seek(0)
local buf_str = buf:string(buf_size)

local size_encoded = stblbin.encode(p, t)
assert(size_encoded == buf_size)

local ptr_str = ffi.string(p, size_encoded)

assert(#buf_str == #ptr_str)
assert(buf_str == ptr_str)

local size_computed = stblbin.size(t)
assert(size_encoded == size_computed)

local size_bound = stblbin.bound(p, size_encoded)
assert(size_bound == size_encoded)
assert(stblbin.bound(p, size_encoded + 1) == size_encoded)
assert(not stblbin.bound(p, size_encoded - 1))
assert(not stblbin.bound(p, 0))

local _t = stblbin.decode(p)
---@cast _t stblbin.Table

local table_util = require("table_util")
assert(table_util.deepequal(t, _t))

return stblbin
