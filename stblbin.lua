local ffi = require("ffi")
local byte = require("byte_new")
local table_util = require("table_util")

local stblbin = {}

-- key types: number, string
-- value types: boolean, number, string, table

--[[
	enum type:
		number = 0
		string = 1
		boolean = 2
		table = 3

	struct Number: Value
		uint8 type
		double value

	struct String: Value
		uint8 type
		uint16 size
		char[size] value

	struct Boolean: Value
		uint8 type
		uint8 value

	struct Table
		uint8 type
		uint16 size
		{Value key, Value|Table value}[size]
]]

local tag_ids = {
	[0] = "number",
	"string",
	"boolean",
	"table",
}
for k, v in pairs(tag_ids) do
	tag_ids[v] = k
end

local pl_enc = {}
local pl_dec = {}

function pl_enc.boolean(p, n) byte.write_int8(p, n and 1 or 0) return 1 end
function pl_enc.number(p, n) byte.write_double_be(p, n) return 8 end

function pl_dec.boolean(p) return byte.read_int8(p) == 1, 1 end
function pl_dec.number(p) return byte.read_double_be(p), 8 end

function pl_enc.string(p, s)
	byte.write_uint16_be(p, #s)
	ffi.copy(p + 2, s, #s)
	return #s + 2
end

function pl_dec.string(p)
	local size = byte.read_uint16_be(p)
	return ffi.string(p + 2, size), size + 2
end

function pl_enc.table(p, tbl)
	local size_p = p
	p = p + 2
	local total_size = 2
	local count = 0
	for k, v in pairs(tbl) do
		local key_size = stblbin.encode(p, k)
		p = p + key_size
		local value_size = stblbin.encode(p, v)
		p = p + value_size
		total_size = total_size + key_size + value_size
		count = count + 1
	end
	byte.write_uint16_be(size_p, count)
	return total_size
end

function pl_dec.table(p)
	local count = byte.read_uint16_be(p)
	p = p + 2
	local total_size = 2
	local tbl = {}
	while count > 0 do
		local k, key_size = stblbin.decode(p)
		p = p + key_size
		local v, value_size = stblbin.decode(p)
		p = p + value_size
		total_size = total_size + key_size + value_size
		tbl[k] = v
		count = count - 1
	end
	return tbl, total_size
end

---@param p ffi.cdata*
---@return any
---@return integer size total read size
function stblbin.decode(p)
	local tag_id = tag_ids[byte.read_uint8(p)]
	local decode = pl_dec[tag_id]
	local obj, size = decode(p + 1)
	return obj, 1 + size
end

---@param p ffi.cdata*
---@param obj any
---@return integer size total write size
function stblbin.encode(p, obj)
	local tag_id = type(obj)
	byte.write_uint8(p, tag_ids[tag_id])
	local encode = pl_enc[tag_id]
	local size = encode(p + 1, obj)
	return 1 + size
end

-- tests

local p = ffi.new("uint8_t[?]", 1e6)

local t = {
	a = 1,
	b = "hi",
	c = true,
	d = {
		q = {},
		1,
	},
	10,
	20,
}
stblbin.encode(p, t)

local _t = stblbin.decode(p)
assert(table_util.deepequal(t, _t))

return stblbin
