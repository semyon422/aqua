local bit = require("bit")
local ffi = require("ffi")

local byte = {}

local bad_numeric_pattern = "bad argument (number or ctype<uint64_t> expected, got %s)"

---@generic T
---@param value T
---@return T
function byte.assert_numeric(value)
	if type(value) == "cdata" then
		assert(
			ffi.istype("int64_t", value) or ffi.istype("uint64_t", value),
			bad_numeric_pattern:format(ffi.typeof(value))
		)
		return value
	end
	assert(
		type(value) == "number",
		bad_numeric_pattern:format(type(value))
	)
	return value
end

assert(pcall(byte.assert_numeric, 0))
assert(pcall(byte.assert_numeric, 0ll))
assert(pcall(byte.assert_numeric, 0ull))
assert(not pcall(byte.assert_numeric, 0i))
assert(not pcall(byte.assert_numeric, "0"))

--------------------------------------------------------------------------------

---@param dst byte.Pointer
---@param src byte.Pointer
---@param len integer
function byte.copy_reverse(dst, src, len)
	---@type byte.Pointer
	dst, src = ffi.cast("uint8_t*", dst), ffi.cast("uint8_t*", src)
	for i = 0, len / 2 - 1 do
		local j = len - 1 - i
		dst[i], dst[j] = src[j], src[i]
	end
end

do
	local buf1, buf2 = ffi.new("uint8_t[4]"), ffi.new("uint8_t[4]")
	ffi.copy(buf1, "\x12\x34\x56\x78", 4)
	byte.copy_reverse(buf2, buf1, 4)
	assert(ffi.string(buf1, 4) == "\x12\x34\x56\x78")
	assert(ffi.string(buf2, 4) == "\x78\x56\x34\x12")

	byte.copy_reverse(buf1, buf1, 4)
	assert(ffi.string(buf1, 4) == "\x78\x56\x34\x12")

	byte.copy_reverse(buf1, buf1, 3)
	assert(ffi.string(buf1, 4) == "\x34\x56\x78\x12")

	byte.copy_reverse(buf1, buf1, 1)
	assert(ffi.string(buf1, 4) == "\x34\x56\x78\x12")
end

--------------------------------------------------------------------------------

ffi.cdef([[
	typedef union {
		int8_t int8;
		uint8_t uint8;
		int16_t int16;
		uint16_t uint16;
		int32_t int32;
		uint32_t uint32;
		int64_t int64;
		uint64_t uint64;
		float _float;
		double _double;
	} byte_ConvUnion;
]])

---@alias byte.Pointer ffi.cdata*|{[integer]: integer}

---@class byte.ConvUnion
---@field int8 integer
---@field uint8 integer
---@field int16 integer
---@field uint16 integer
---@field int32 integer
---@field uint32 integer
---@field int64 integer
---@field uint64 integer
---@field _float number
---@field _double number

---@enum (key) byte.Types
local key_bytes = {
	int8 = 1,
	uint8 = 1,
	int16 = 2,
	uint16 = 2,
	int32 = 4,
	uint32 = 4,
	int64 = 8,
	uint64 = 8,
	_float = 4,
	_double = 8,
}

local conv_union = ffi.new("byte_ConvUnion")
---@cast conv_union -ffi.cdata*, +byte.ConvUnion

local fallback_buf = ffi.new("uint8_t[?]", ffi.sizeof("byte_ConvUnion"))
---@cast fallback_buf -ffi.cdata*, +byte.ConvUnion

---@type {[integer]: byte.Pointer}
local conv_union_byte_p = ffi.new("uint8_t*[1]")
local conv_union_p = ffi.cast("byte_ConvUnion**", conv_union_byte_p)

---@param p byte.Pointer?
---@return byte.ConvUnion
function byte.union_le(p)
	conv_union_byte_p[0] = p or fallback_buf
	return conv_union_p[0][0]
end

do
	byte.union_le().int16 = -1
	assert(byte.union_le().int16 == -1)
	assert(byte.union_le().uint16 == 65535)
end

---@type byte.ConvUnion|{[1]: byte.Pointer}
local conv_be_proxy = setmetatable({fallback_buf}, {
	---@param t {[1]: byte.Pointer}
	---@param k byte.Types
	__index = function(t, k)
		byte.copy_reverse(conv_union, t[1], assert(key_bytes[k]))
		return conv_union[k]
	end,
	---@param t {[1]: byte.Pointer}
	---@param k byte.Types
	---@param v number
	__newindex = function(t, k, v)
		conv_union[k] = v ---@diagnostic disable-line: no-unknown
		byte.copy_reverse(t[1], conv_union, assert(key_bytes[k]))
	end
})

---@param p byte.Pointer?
---@return byte.ConvUnion
function byte.union_be(p)
	conv_be_proxy[1] = p or fallback_buf
	return conv_be_proxy
end

do
	byte.union_be().int16 = -1
	assert(byte.union_be().int16 == -1)
	assert(byte.union_be().uint16 == 65535)
end

--------------------------------------------------------------------------------

-- https://stackoverflow.com/questions/32174991/converting-n-bit-integer-from-unsigned-to-signed

---@param n integer
---@param b integer bytes
---@return integer
function byte.to_signed(n, b)
	if b == 4 or b < 4 and n < bit.lshift(0x80, (b - 1) * 8) then
		return bit.tobit(n)
	end
	return bit.bor(n, bit.bnot(bit.lshift(1, b * 8 - 1) - 1))
end

assert(byte.to_signed(0x7F, 1) == 0x7F)
assert(byte.to_signed(0x7FFF, 2) == 0x7FFF)
assert(byte.to_signed(0x7FFFFFFF, 4) == 0x7FFFFFFF)
assert(byte.to_signed(0xFF, 1) == -1)
assert(byte.to_signed(0xFFFF, 2) == -1)
assert(byte.to_signed(0xFFFFFFFF, 4) == -1)
assert(byte.to_signed(0x80, 1) == -128)
assert(byte.to_signed(0x8000, 2) == -32768)
assert(byte.to_signed(0x80000000, 4) == -2147483648)

---@param n integer
---@param b integer bytes
---@return integer
function byte.to_unsigned(n, b)
	if n >= 0 then
		return bit.tobit(n)
	end
	return tonumber(bit.band(n, bit.lshift(1ll, b * 8) - 1)) ---@diagnostic disable-line: return-type-mismatch
end

assert(byte.to_unsigned(0x7F, 1) == 0x7F)
assert(byte.to_unsigned(0x7FFF, 2) == 0x7FFF)
assert(byte.to_unsigned(0x7FFFFFFF, 4) == 0x7FFFFFFF)
assert(byte.to_unsigned(-1, 1) == 0xFF)
assert(byte.to_unsigned(-1, 2) == 0xFFFF)
assert(byte.to_unsigned(-1, 4) == 0xFFFFFFFF)
assert(byte.to_unsigned(-128, 1) == 0x80)
assert(byte.to_unsigned(-32768, 2) == 0x8000)
assert(byte.to_unsigned(-2147483648, 4) == 0x80000000)

--------------------------------------------------------------------------------

---@generic T
---@param ... T?
---@return {n: integer, [integer]: T}
local function pack(...)
	return {n = select("#", ...), ...}
end

---@generic T
---@param p T
---@param size integer
---@return fun(bytes: integer): T?, string?
function byte.seeker(p, size)
	local offset = 0
	---@param bytes integer
	return function(bytes)
		local offset_new = offset + bytes
		if offset_new > size or offset_new < 0 then
			return
		end
		---@type any
		local _p = p + offset
		offset = offset_new
		return _p
	end
end

do
	local f = byte.seeker(0, 10)

	assert(f(1) == 0)
	assert(f(2) == 1)
	assert(f(4) == 3)
	assert(f(8) == nil)
	assert(f(2) == 7)
	assert(f(-8) == 9)
	assert(f(-2) == nil)
end

---@param seek fun(bytes: integer): byte.Pointer?, string?
---@param proc function
---@return boolean
---@return integer size total processed size
---@return any ...
function byte.apply(seek, proc)
	local _p = assert(seek(0))

	local ok = true
	local offset = 0

	---@type {n: integer, [integer]: any}
	local ret = {}

	---@type fun(p: byte.Pointer): integer?
	local iter = coroutine.wrap(function()
		ret = pack(proc())
	end)

	while true do
		local s = iter(_p)
		if not s then
			break
		end
		_p = seek(s)
		if not _p then
			ok = false
			break
		end
		offset = offset + s
	end

	return ok, offset, unpack(ret, 1, ret.n)
end

do
	local rets = {10, 100}
	local ok, size, ret1, ret2 = byte.apply(function(bytes)
		if bytes == 0 then return {} end
		return table.remove(rets)
	end, function()
		return coroutine.yield(1) + coroutine.yield(2), "test"
	end)

	assert(ok == true)
	assert(size == 3)
	assert(ret1 == 110)
	assert(ret2 == "test")
end

do
	local rets = {10, nil}
	local ok, size, ret = byte.apply(function(bytes)
		if bytes == 0 then return {} end
		return table.remove(rets)
	end, function()
		return coroutine.yield(1) + coroutine.yield(2)
	end)

	assert(ok == false)
	assert(size == 1)
	assert(ret == nil)
end

--------------------------------------------------------------------------------

---@class byte.Buffer: ffi.cdata*
local Buffer = {}

function Buffer:assert_freed()
	assert(self.size ~= 0, "buffer was already freed")
end

local _total = 0

---@return integer
function Buffer.total()
	return _total
end

---@param size integer
---@return byte.Buffer
function Buffer:resize(size)
	self:assert_freed()
	byte.assert_numeric(size)
	assert(size > 0, "buffer size must be greater than zero")

	---@type ffi.cdata*
	local p = ffi.C.realloc(self.ptr, size)
	assert(p ~= nil, "allocation error")
	self.ptr = p

	_total = _total + size - self.size
	self.size = size

	self.offset = self.offset < size and self.offset or size

	return self
end

function Buffer:free()
	self:assert_freed()

	ffi.C.free(self.ptr)
	ffi.gc(self, nil)

	_total = _total - self.size

	self.size = 0
end

---@param state boolean?
---@return byte.Buffer
function Buffer:gc(state)
	self:assert_freed()

	if state then
		ffi.gc(self, self.free)
	else
		ffi.gc(self, nil)
	end

	return self
end

---@param offset integer
---@return byte.Buffer
function Buffer:seek(offset)
	self:assert_freed()
	byte.assert_numeric(offset)
	assert(offset >= 0 and offset <= self.size, "attempt to perform seek outside buffer bounds")

	self.offset = offset

	return self
end

---@param s string
---@param len integer?
---@return byte.Buffer
function Buffer:fill(s, len)
	self:assert_freed()

	local length = len or #s
	local offset = self.offset ---@diagnostic disable-line: no-unknown
	assert(offset + length <= self.size, "attempt to write outside buffer bounds")

	self.offset = offset + length

	ffi.copy(self.ptr + offset, s, length)

	return self
end

---@param length integer
---@return string
function Buffer:string(length)
	self:assert_freed()
	byte.assert_numeric(length)

	local offset = self.offset

	assert(length >= 0, "length cannot be less than zero")
	assert(offset + length <= self.size, "attempt to read after end of buffer")

	self.offset = offset + length

	return ffi.string(self.ptr + offset, length)
end

---@param length integer
---@return string
function Buffer:cstring(length)
	self:assert_freed()
	byte.assert_numeric(length)

	local offset = self.offset

	assert(length >= 0, "length cannot be less than zero")
	assert(offset + length <= self.size, "attempt to read after end of buffer")

	self.offset = offset + length

	local s = ffi.string(self.ptr + offset) -- !!!
	if #s > length then
		return ffi.string(self.ptr + offset, length)
	end

	return s
end

local types = {
	[1] = {"uint8", "int8"},
	[2] = {"uint16_le", "uint16_be", "int16_le", "int16_be"},
	[4] = {"uint32_le", "uint32_be", "int32_le", "int32_be", "_float_le", "_float_be"},
	[8] = {"uint64_le", "uint64_be", "int64_le", "int64_be", "_double_le", "_double_be"},
}

for bytes, _types in pairs(types) do
	for _, _type in ipairs(_types) do
		local t, en = _type:match("^(.+)_(.+)$")
		t = t or _type
		local is_be = en == "be"
		Buffer[_type:gsub("^_", "")] = function(self, n) ---@diagnostic disable-line: no-unknown
			---@type byte.Pointer
			local p = self.ptr + self.offset
			self:seek(self.offset + bytes)

			local union = is_be and byte.union_be(p) or byte.union_le(p)

			if n then
				union[t] = n
				return self
			end
			return union[t]
		end
	end
end

--------------------------------------------------------------------------------

ffi.cdef("void * malloc(size_t size);")
ffi.cdef("void * realloc(void * ptr, size_t newsize);")
ffi.cdef("void free(void * ptr);")

ffi.cdef("typedef struct {unsigned char * ptr; size_t size; size_t offset;} byte_Buffer;")

local mt = {}

---@param _ any
---@param key string
---@return function
function mt.__index(_, key)
	return Buffer[key]
end

-- buffer ctype
byte.buffer_t = ffi.metatype(ffi.typeof("byte_Buffer"), mt)

-- buffer constructor
---@param size integer
---@return ffi.cdata*
function byte.buffer(size)
	byte.assert_numeric(size)
	assert(size > 0, "buffer size must be greater than zero")

	---@type ffi.cdata*
	local p = ffi.C.malloc(size)
	assert(p ~= nil, "allocation error")

	local b = byte.buffer_t(p, size, 0)
	ffi.gc(b, b.free)

	_total = _total + size

	return b
end

local b = byte.buffer(#types * 8)
ffi.fill(b.ptr, b.size, 0x80)

assert(b:uint8() == 0x80)
assert(b:uint16_le() == 0x8080)
assert(b:uint16_be() == 0x8080)
assert(b:uint32_le() == 0x80808080)
assert(b:uint32_be() == 0x80808080)
assert(b:uint64_le() == 0x8080808080808080ULL)
assert(b:uint64_be() == 0x8080808080808080ULL)
assert(b:int8() == byte.to_signed(0x80, 1))
assert(b:int16_le() == byte.to_signed(0x8080, 2))
assert(b:int16_be() == byte.to_signed(0x8080, 2))
assert(b:int32_le() == byte.to_signed(0x80808080, 4))
assert(b:int32_be() == byte.to_signed(0x80808080, 4))
assert(b:int64_le() == 0x8080808080808080LL)
assert(b:int64_be() == 0x8080808080808080LL)

ffi.fill(b.ptr, b.size, 0x7F)
b:seek(0)

assert(b:uint8() == 0x7F)
assert(b:uint16_le() == 0x7F7F)
assert(b:uint16_be() == 0x7F7F)
assert(b:uint32_le() == 0x7F7F7F7F)
assert(b:uint32_be() == 0x7F7F7F7F)
assert(b:uint64_le() == 0x7F7F7F7F7F7F7F7FULL)
assert(b:uint64_be() == 0x7F7F7F7F7F7F7F7FULL)
assert(b:int8() == 0x7F)
assert(b:int16_le() == 0x7F7F)
assert(b:int16_be() == 0x7F7F)
assert(b:int32_le() == 0x7F7F7F7F)
assert(b:int32_be() == 0x7F7F7F7F)
assert(b:int64_le() == 0x7F7F7F7F7F7F7F7FLL)
assert(b:int64_be() == 0x7F7F7F7F7F7F7F7FLL)

b:seek(0):float_le(1.125):float_be(1.125):seek(0)
assert(b:float_le() == 1.125)
assert(b:float_be() == 1.125)

b:seek(0):double_le(1.125):double_be(1.125):seek(0)
assert(b:double_le() == 1.125)
assert(b:double_be() == 1.125)

b:seek(0)
b:uint64_be(0x0123456789ABCDEFULL)
assert(b:seek(0):uint16_le() == 0x2301)
assert(b:seek(0):uint32_le() == 0x67452301)
assert(b:seek(0):uint64_le() == 0xEFCDAB8967452301ULL)

return byte
