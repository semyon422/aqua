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
	for i = 0, math.ceil(len / 2) - 1 do
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

	byte.copy_reverse(buf1, buf2, 1)
	assert(ffi.string(buf1, 4) == "\x78\x56\x78\x12")
end

--------------------------------------------------------------------------------

-- https://stackoverflow.com/questions/32174991/converting-n-bit-integer-from-unsigned-to-signed

---@param n integer
---@param b integer bytes
---@return integer
function byte.to_signed(n, b)
	local mask = bit.lshift(1, b * 8 - 1)
	if b == 4 or bit.band(n, mask) == 0 then
		return bit.tobit(n)
	end
	return bit.bxor(n, mask) - mask
end

assert(byte.to_signed(0x7F, 1) == 0x7F)
assert(byte.to_signed(0x7FFF, 2) == 0x7FFF)
assert(byte.to_signed(0x7FFFFFFF, 4) == 0x7FFFFFFF)
assert(byte.to_signed(0xFF, 1) == -1)
assert(byte.to_signed(0xFFFF, 2) == -1)
assert(byte.to_signed(0xFFFFFFFF, 4) == -1)
assert(byte.to_signed(0x80, 1) == -0x80)
assert(byte.to_signed(0x8000, 2) == -0x8000)
assert(byte.to_signed(0x80000000, 4) == -0x80000000)

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
assert(byte.to_unsigned(-0x80, 1) == 0x80)
assert(byte.to_unsigned(-0x8000, 2) == 0x8000)
assert(byte.to_unsigned(-0x80000000, 4) == 0x80000000)

--------------------------------------------------------------------------------

ffi.cdef([[
	typedef union {
		int8_t i8;
		uint8_t u8;
		int16_t i16;
		uint16_t u16;
		int32_t i32;
		uint32_t u32;
		int64_t i64;
		uint64_t u64;
		float f32;
		double f64;
	} byte_ConvUnion;
]])

---@alias byte.Pointer ffi.cdata*|{[integer]: integer}

---@class byte.ConvUnion
---@field i8 integer
---@field u8 integer
---@field i16 integer
---@field u16 integer
---@field i32 integer
---@field u32 integer
---@field i64 integer
---@field u64 integer
---@field f32 number
---@field f64 number

---@enum (key) byte.Type
local type_bytes = {
	i8 = 1,
	u8 = 1,
	i16 = 2,
	u16 = 2,
	i32 = 4,
	u32 = 4,
	i64 = 8,
	u64 = 8,
	f32 = 4,
	f64 = 8,
}

---@param k string
---@return integer
local function sizeof(k)
	return assert(type_bytes[k])
end

local conv_union = ffi.new("byte_ConvUnion")
---@cast conv_union -ffi.cdata*, +byte.ConvUnion

local fallback_buf = ffi.new("uint8_t[?]", ffi.sizeof("byte_ConvUnion"))
---@cast fallback_buf -ffi.cdata*, +byte.ConvUnion

---@type {[integer]: byte.Pointer}
local conv_union_byte_p = ffi.new("const uint8_t*[1]")
local conv_union_p = ffi.cast("byte_ConvUnion**", conv_union_byte_p)

function byte.hex(p, bytes)
	p = ffi.cast("uint8_t*", p)
	---@type string[]
	local t = {}
	for i = 1, bytes do
		t[i] = ("%02X"):format(p[i - 1])
	end
	return table.concat(t)
end

---@param p byte.Pointer|string?
---@return byte.ConvUnion
function byte.union_le(p)
	conv_union_byte_p[0] = p or fallback_buf
	return conv_union_p[0][0]
end

do
	local union = byte.union_le()

	union.u64 = 0x8300000082008180ULL
	assert(byte.hex(union, 8) == "8081008200000083")

	assert(union.u8 == 0x80)
	assert(union.u16 == 0x8180)
	assert(union.u32 == 0x82008180)
	assert(union.u64 == 0x8300000082008180ULL)

	assert(union.i8 == byte.to_signed(0x80, 1))
	assert(union.i16 == byte.to_signed(0x8180, 2))
	assert(union.i32 == byte.to_signed(0x82008180, 4))
	assert(union.i64 == 0x8300000082008180LL)

	union.u64 = 0x7300000072007170ULL
	assert(byte.hex(union, 8) == "7071007200000073")

	assert(union.u8 == 0x70)
	assert(union.u16 == 0x7170)
	assert(union.u32 == 0x72007170)
	assert(union.u64 == 0x7300000072007170ULL)

	assert(union.i8 == byte.to_signed(0x70, 1))
	assert(union.i16 == byte.to_signed(0x7170, 2))
	assert(union.i32 == byte.to_signed(0x72007170, 4))
	assert(union.i64 == 0x7300000072007170LL)

	union.f32 = 1.125
	assert(byte.hex(union, 4) == "0000903F")
	assert(union.u32 == 0x3F900000)

	union.f64 = 1.125
	assert(byte.hex(union, 8) == "000000000000F23F")
	assert(union.u64 == 0x3FF2000000000000ULL)

	assert(byte.union_le("\xFF").i8 == -1)
end

---@type byte.ConvUnion|{[1]: byte.Pointer|string}
local conv_be_proxy = setmetatable({fallback_buf}, {
	---@param t {[1]: byte.Pointer}
	---@param k string
	__index = function(t, k)
		byte.copy_reverse(conv_union, t[1], sizeof(k))
		return conv_union[k]
	end,
	---@param t {[1]: byte.Pointer}
	---@param k string
	---@param v number
	__newindex = function(t, k, v)
		conv_union[k] = v ---@diagnostic disable-line: no-unknown
		byte.copy_reverse(t[1], conv_union, sizeof(k))
	end
})

---@param p byte.Pointer|string?
---@return byte.ConvUnion
function byte.union_be(p)
	conv_be_proxy[1] = p or fallback_buf
	return conv_be_proxy
end

do
	local union = byte.union_be()

	union.u64 = 0x8081008200000083ULL
	assert(byte.hex(union[1], 8) == "8081008200000083")

	assert(union.u8 == 0x80)
	assert(union.u16 == 0x8081)
	assert(union.u32 == 0x80810082)
	assert(union.u64 == 0x8081008200000083ULL)

	assert(union.i8 == byte.to_signed(0x80, 1))
	assert(union.i16 == byte.to_signed(0x8081, 2))
	assert(union.i32 == byte.to_signed(0x80810082, 4))
	assert(union.i64 == 0x8081008200000083LL)

	union.u64 = 0x7071007200000073ULL
	assert(byte.hex(union[1], 8) == "7071007200000073")

	assert(union.u8 == 0x70)
	assert(union.u16 == 0x7071)
	assert(union.u32 == 0x70710072)
	assert(union.u64 == 0x7071007200000073ULL)

	assert(union.i8 == byte.to_signed(0x70, 1))
	assert(union.i16 == byte.to_signed(0x7071, 2))
	assert(union.i32 == byte.to_signed(0x70710072, 4))
	assert(union.i64 == 0x7071007200000073LL)

	union.f32 = 1.125
	assert(byte.hex(union[1], 4) == "3F900000")
	assert(union.u32 == 0x3F900000)

	union.f64 = 1.125
	assert(byte.hex(union[1], 8) == "3FF2000000000000")
	assert(union.u64 == 0x3FF2000000000000ULL)

	assert(byte.union_be("\xFF").i8 == -1)
end

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

---@generic T
---@param buf byte.Buffer
---@param max_size integer
---@return fun(bytes: integer): T?, string?
function byte.stretchy_seeker(buf, max_size)
	---@param bytes integer
	return function(bytes)
		local offset = tonumber(buf.offset + bytes)
		---@cast offset -?
		if offset > max_size or offset < 0 then
			return
		end
		local size = tonumber(buf.size)
		---@cast size -?
		if offset > size then
			buf:resize(math.min(math.max(size * 2, offset), max_size))
		end
		---@type any
		local p = buf:cur()
		buf:seek(offset)
		return p
	end
end

---@param seek fun(bytes: integer): byte.Pointer?, string?
---@param proc function
---@param ... any
---@return boolean
---@return integer size total processed size
---@return any ...
function byte.apply(seek, proc, ...)
	---@type byte.Pointer
	local _p

	local ok = true
	local offset = 0

	---@type {n: integer, [integer]: any}
	local ret = {}

	---@type fun(p: byte.Pointer): integer?
	local iter = coroutine.wrap(function(...)
		ret = pack(proc(...))
	end)

	local s = iter(...)

	while true do
		if not s then
			break
		end
		_p = seek(s)
		if not _p then
			ok = false
			break
		end
		offset = offset + s
		s = iter(_p)
	end

	return ok, offset, unpack(ret, 1, ret.n)
end

do
	local rets = {10, 100}
	local ok, size, ret1, ret2 = byte.apply(function(bytes)
		if bytes == 0 then return {} end
		return table.remove(rets)
	end, function(init)
		return init + coroutine.yield(1) + coroutine.yield(2), "test"
	end, 1000)

	assert(ok == true)
	assert(size == 3)
	assert(ret1 == 1110)
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
---@field char byte.Pointer
---@field size integer
---@field offset integer
---@field endianness integer
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

	self.offset = 0
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

---@return ffi.cdata*
function Buffer:cur()
	return self.ptr + self.offset
end

---@param s string
---@param len integer?
---@return byte.Buffer
function Buffer:fill(s, len)
	self:assert_freed()

	local length = len or #s
	local offset = self.offset ---@diagnostic disable-line: no-unknown
	assert(offset + length <= self.size, "attempt to write outside buffer bounds")

	ffi.copy(self:cur(), s, length)

	self.offset = offset + length

	return self
end

---@param length integer
---@param cstr boolean?
---@return string
function Buffer:string(length, cstr)
	self:assert_freed()
	byte.assert_numeric(length)

	local offset = self.offset

	assert(length >= 0, "length cannot be less than zero")
	assert(offset + length <= self.size, "attempt to read after end of buffer")

	local p = self:cur()
	self.offset = offset + length

	if cstr then
		length = tonumber(ffi.C.strnlen(p, length))
	end

	return ffi.string(p, length)
end

function Buffer:is_be()
	return self.endianness == 1
end

function Buffer:set_be(is_be)
	self.endianness = (not not is_be and 1 or 0)
end

function Buffer:get_union()
	local p = self:cur()
	return self:is_be() and byte.union_be(p) or byte.union_le(p)
end

---@param t byte.Type
---@return number
function Buffer:read(t)
	local union = self:get_union()
	self:seek(self.offset + sizeof(t))
	return union[t]
end

---@param t byte.Type
---@param n number
---@return byte.Buffer
function Buffer:write(t, n)
	local union = self:get_union()
	self:seek(self.offset + sizeof(t))
	union[t] = n ---@diagnostic disable-line: no-unknown
	return self
end

--------------------------------------------------------------------------------

ffi.cdef("void * malloc(size_t size);")
ffi.cdef("void * realloc(void * ptr, size_t newsize);")
ffi.cdef("void free(void * ptr);")
ffi.cdef("size_t strnlen(const char * str, size_t strsz);")

ffi.cdef([[
	typedef struct {
		unsigned char * ptr;
		size_t size;
		size_t offset;
		uint8_t endianness;
	} byte_Buffer;
]])

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
---@return byte.Buffer
function byte.buffer(size)
	byte.assert_numeric(size)
	assert(size > 0, "buffer size must be greater than zero")

	---@type ffi.cdata*
	local p = ffi.C.malloc(size)
	assert(p ~= nil, "allocation error")

	local b = byte.buffer_t(p, size, 0)
	ffi.gc(b, b.free)
	---@cast b byte.Buffer

	_total = _total + size

	return b
end

local b = byte.buffer(8)
assert(b.size == 8)
assert(Buffer.total(), 8)

b:fill("\x01\x23\x45\x67\x89\xAB\xCD\xEF")
assert(b.offset == 8)

b:resize(16)
assert(b.size == 16)
assert(Buffer.total(), 16)

b:fill("\x62\x79\x74\x65\0\0\0\0")
assert(b.offset == 16)

b:seek(0)
assert(b.offset == 0)

assert(b:read("i32") == 0x67452301)
assert(b.offset == 4)

assert(not b:is_be())
b:set_be(true)
assert(b:is_be())

assert(b:read("i32") == byte.to_signed(0x89ABCDEF, 4))
assert(b.offset == 8)

b:seek(0)
b:write("f64", math.pi)
b:seek(0)
assert(b:read("f64") == math.pi)

assert(b:string(8, true) == "byte")
b:seek(8)
assert(b:string(8) == "byte\0\0\0\0")

b:free()
assert(b.offset == 0)
assert(b.size == 0)

assert(Buffer.total(), 0)

do
	local buf = byte.buffer(10)
	local f = byte.stretchy_seeker(buf, 100)

	assert(f(1))
	assert(buf.offset == 1)
	assert(buf.size == 10)
	assert(f(10))
	assert(buf.offset == 11)
	assert(buf.size == 20)
	assert(f(40))
	assert(buf.offset == 51)
	assert(buf.size == 51)
	assert(f(1))
	assert(buf.offset == 52)
	assert(buf.size == 100)
	assert(not f(50))
	assert(buf.offset == 52)
	assert(buf.size == 100)
end

return byte
