local bit = require("bit")
local ffi = require("ffi")

local bad_numeric_pattern = "bad argument (number or ctype<uint64_t> expected, got %s)"

local assert_numeric
do
	local uint64_t = ffi.typeof("uint64_t")

	function assert_numeric(value)
		if type(value) == "cdata" then
			return assert(
				ffi.istype(uint64_t, value),
				bad_numeric_pattern:format(ffi.typeof(value))
			)
		end
		return assert(
			tonumber(value),
			bad_numeric_pattern:format(type(value))
		)
	end
end

local copy_reverse
do
	local buf = ffi.new("uint8_t[?]", 8)
	function copy_reverse(dst, src, len)
		assert(len >= 2, len <= 8 and len % 2 == 0)
		ffi.copy(buf, src, len)
		for i = 0, len / 2 - 1 do
			buf[i], buf[len - 1 - i] = buf[len - 1 - i], buf[i]
		end
		ffi.copy(dst, buf, len)
	end
end

--------------------------------------------------------------------------------

local byte = {}

---@param p ffi.cdata*
---@param n number
---@param bits boolean?
---@return table
function byte.bytes(p, n, bits)
	local list = {}
	for i = 1, n do
		local v = p[i - 1]
		if not bits then
			list[i] = v
		else
			for j = 1, 8 do
				list[(i - 1) * 8 + 9 - j] = bit.band(bit.rshift(v, j - 1), 1)
			end
		end
	end
	return list
end

-- https://stackoverflow.com/questions/32174991/converting-n-bit-integer-from-unsigned-to-signed

---@param n number
---@param b number
---@return number
function byte.to_signed(n, b)
	if b == 4 or b < 4 and n < bit.lshift(0x80, (b - 1) * 8) then
		return bit.tobit(n)
	end
	return bit.bor(n, bit.bnot(bit.lshift(1, b * 8 - 1) - 1))
end

---@param p ffi.cdata*
---@return number
function byte.read_uint8(p)
	return p[0]
end

---@param p ffi.cdata*
---@param n number
function byte.write_uint8(p, n)
	p[0] = bit.band(n, 0xFF)
end

---@param p ffi.cdata*
---@return number
function byte.read_int8(p)
	return byte.to_signed(p[0], 1)
end

---@param p ffi.cdata*
---@param n number
function byte.write_int8(p, n)
	p[0] = bit.band(n, 0xFF)
end

---@param p ffi.cdata*
---@return number
function byte.read_uint16_le(p)
	return bit.lshift(p[1], 8) + p[0]
end

---@param p ffi.cdata*
---@param n number
function byte.write_uint16_le(p, n)
	p[0] = bit.band(n, 0x00FF)
	p[1] = bit.rshift(bit.band(n, 0xFF00), 8)
end

---@param p ffi.cdata*
---@return number
function byte.read_uint16_be(p)
	return bit.lshift(p[0], 8) + p[1]
end

---@param p ffi.cdata*
---@param n number
function byte.write_uint16_be(p, n)
	p[0] = bit.rshift(bit.band(n, 0xFF00), 8)
	p[1] = bit.band(n, 0x00FF)
end

---@param p ffi.cdata*
---@return number
function byte.read_int16_le(p)
	return byte.to_signed(byte.read_uint16_le(p), 2)
end

byte.write_int16_le = byte.write_uint16_le

---@param p ffi.cdata*
---@return number
function byte.read_int16_be(p)
	return byte.to_signed(byte.read_uint16_be(p), 2)
end

byte.write_int16_be = byte.write_uint16_be

---@param p ffi.cdata*
---@return number
function byte.read_int32_le(p)
	return
		bit.lshift(p[3], 24)
		+ bit.lshift(p[2], 16)
		+ bit.lshift(p[1], 8)
		+ p[0]
end

---@param p ffi.cdata*
---@param n number
function byte.write_int32_le(p, n)
	p[0] = bit.band(n, 0x000000FF)
	p[1] = bit.rshift(bit.band(n, 0x0000FF00), 8)
	p[2] = bit.rshift(bit.band(n, 0x00FF0000), 16)
	p[3] = bit.rshift(bit.band(n, 0xFF000000), 24)
end

---@param p ffi.cdata*
---@return number
function byte.read_int32_be(p)
	return
		bit.lshift(p[0], 24)
		+ bit.lshift(p[1], 16)
		+ bit.lshift(p[2], 8)
		+ p[3]
end

---@param p ffi.cdata*
---@param n number
function byte.write_int32_be(p, n)
	p[0] = bit.rshift(bit.band(n, 0xFF000000), 24)
	p[1] = bit.rshift(bit.band(n, 0x00FF0000), 16)
	p[2] = bit.rshift(bit.band(n, 0x0000FF00), 8)
	p[3] = bit.band(n, 0x000000FF)
end

do
	local int32_pointer = ffi.new("int32_t[1]")
	local uint32_pointer = ffi.cast("uint32_t*", int32_pointer)

	---@param p ffi.cdata*
	---@return number
	function byte.read_uint32_le(p)
		int32_pointer[0] = byte.read_int32_le(p)
		return uint32_pointer[0]
	end

	byte.write_uint32_le = byte.write_int32_le

	---@param p ffi.cdata*
	---@return number
	function byte.read_uint32_be(p)
		int32_pointer[0] = byte.read_int32_be(p)
		return uint32_pointer[0]
	end

	byte.write_uint32_be = byte.write_int32_be
end

do
	local int64_pointer = ffi.new("int64_t[1]")
	local uint64_pointer = ffi.new("uint64_t[1]")

	---@param p ffi.cdata*
	---@return number
	function byte.read_int64_le(p)
		ffi.copy(int64_pointer, p, 8)
		return int64_pointer[0]
	end

	---@param p ffi.cdata*
	---@param n number
	function byte.write_int64_le(p, n)
		int64_pointer[0] = n
		ffi.copy(p, int64_pointer, 8)
	end

	---@param p ffi.cdata*
	---@return number
	function byte.read_int64_be(p)
		copy_reverse(int64_pointer, p, 8)
		return int64_pointer[0]
	end

	---@param p ffi.cdata*
	---@param n number
	function byte.write_int64_be(p, n)
		int64_pointer[0] = n
		copy_reverse(p, int64_pointer, 8)
	end

	---@param p ffi.cdata*
	---@return number
	function byte.read_uint64_le(p)
		ffi.copy(uint64_pointer, p, 8)
		return uint64_pointer[0]
	end

	---@param p ffi.cdata*
	---@param n number
	function byte.write_uint64_le(p, n)
		uint64_pointer[0] = n
		ffi.copy(p, uint64_pointer, 8)
	end

	---@param p ffi.cdata*
	---@return number
	function byte.read_uint64_be(p)
		copy_reverse(uint64_pointer, p, 8)
		return uint64_pointer[0]
	end

	---@param p ffi.cdata*
	---@param n number
	function byte.write_uint64_be(p, n)
		uint64_pointer[0] = n
		copy_reverse(p, uint64_pointer, 8)
	end
end

--------------------------------------------------------------------------------

do
	local uint32_pointer = ffi.new("uint32_t[1]")
	local float_pointer = ffi.cast("float*", uint32_pointer)

	function byte.uint32_to_float(n)
		uint32_pointer[0] = n
		return float_pointer[0]
	end

	function byte.float_to_uint32(n)
		float_pointer[0] = n
		return uint32_pointer[0]
	end
end

---@param p ffi.cdata*
---@return number
function byte.read_float_le(p)
	return byte.uint32_to_float(byte.read_int32_le(p))
end

---@param p ffi.cdata*
---@param n number
function byte.write_float_le(p, n)
	return byte.write_int32_le(p, byte.float_to_uint32(n))
end

---@param p ffi.cdata*
---@return number
function byte.read_float_be(p)
	return byte.uint32_to_float(byte.read_int32_be(p))
end

---@param p ffi.cdata*
---@param n number
function byte.write_float_be(p, n)
	return byte.write_int32_be(p, byte.float_to_uint32(n))
end

--------------------------------------------------------------------------------

do
	local uint64_pointer = ffi.new("uint64_t[1]")
	local double_pointer = ffi.cast("double*", uint64_pointer)

	function byte.uint64_to_double(n)
		uint64_pointer[0] = n
		return double_pointer[0]
	end

	function byte.double_to_uint64(n)
		double_pointer[0] = n
		return uint64_pointer[0]
	end
end

---@param p ffi.cdata*
---@return number
function byte.read_double_le(p)
	return byte.uint64_to_double(byte.read_uint64_le(p))
end

---@param p ffi.cdata*
---@param n number
function byte.write_double_le(p, n)
	return byte.write_uint64_le(p, byte.double_to_uint64(n))
end

---@param p ffi.cdata*
---@return number
function byte.read_double_be(p)
	return byte.uint64_to_double(byte.read_uint64_be(p))
end

---@param p ffi.cdata*
---@param n number
function byte.write_double_be(p, n)
	return byte.write_uint64_be(p, byte.double_to_uint64(n))
end

--------------------------------------------------------------------------------

local buffer = {}

function buffer:assert_freed()
	assert(self.size ~= 0, "buffer was already freed")
end

local _total = ffi.new("size_t")

---@return ffi.cdata*
function buffer.total()
	return _total
end

---@param newsize number
---@return table
function buffer:resize(newsize)
	self:assert_freed()
	assert_numeric(newsize)
	assert(newsize > 0, "buffer size must be greater than zero")

	local pointer = ffi.C.realloc(self.pointer, newsize)
	assert(pointer ~= nil, "allocation error")
	self.pointer = pointer

	_total = _total + newsize - self.size
	self.size = newsize

	self.offset = self.offset < newsize and self.offset or newsize

	return self
end

function buffer:free()
	self:assert_freed()

	ffi.C.free(self.pointer)
	ffi.gc(self, nil)

	_total = _total - self.size

	self.size = 0
end

---@param state boolean?
---@return table
function buffer:gc(state)
	self:assert_freed()

	if state then
		ffi.gc(self, self.free)
	else
		ffi.gc(self, nil)
	end

	return self
end

---@param offset number
---@return table
function buffer:seek(offset)
	self:assert_freed()
	assert_numeric(offset)
	assert(offset >= 0 and offset <= self.size, "attempt to perform seek outside buffer bounds")

	self.offset = offset

	return self
end

---@param s string
---@param len number?
---@return table
function buffer:fill(s, len)
	self:assert_freed()

	local length = len or #s
	local offset = self.offset
	assert(offset + length <= self.size, "attempt to write outside buffer bounds")

	self.offset = offset + length

	ffi.copy(self.pointer + offset, s, length)

	return self
end

---@param length number
---@return string
function buffer:string(length)
	self:assert_freed()
	assert_numeric(length)

	local offset = self.offset

	assert(length >= 0, "length cannot be less than zero")
	assert(offset + length <= self.size, "attempt to read after end of buffer")

	self.offset = offset + length

	return ffi.string(self.pointer + offset, length)
end

---@param length number
---@return string
function buffer:cstring(length)
	self:assert_freed()
	assert_numeric(length)

	local offset = self.offset

	assert(length >= 0, "length cannot be less than zero")
	assert(offset + length <= self.size, "attempt to read after end of buffer")

	self.offset = offset + length

	local s = ffi.string(self.pointer + offset)
	if #s > length then
		return ffi.string(self.pointer + offset, length)
	end

	return s
end

local types = {
	[1] = {"uint8", "int8"},
	[2] = {"uint16_le", "uint16_be", "int16_le", "int16_be"},
	[4] = {"uint32_le", "uint32_be", "int32_le", "int32_be", "float_le", "float_be"},
	[8] = {"uint64_le", "uint64_be", "int64_le", "int64_be", "double_le", "double_be"},
}

for bytes, _types in pairs(types) do
	for _, _type in ipairs(_types) do
		buffer[_type] = function(self, n)
			local p = self.pointer + self.offset
			self:seek(self.offset + bytes)
			if n then
				byte["write_" .. _type](p, n)
				return self
			end
			return byte["read_" .. _type](p)
		end
	end
end

--------------------------------------------------------------------------------

ffi.cdef("void * malloc(size_t size);")
ffi.cdef("void * realloc(void * ptr, size_t newsize);")
ffi.cdef("void free(void * ptr);")

ffi.cdef("typedef struct {unsigned char * pointer; size_t size; size_t offset;} buffer_t__byte_new;")

local mt = {}

---@param _ any
---@param key string
---@return function
function mt.__index(_, key)
	return buffer[key]
end

-- buffer ctype
byte.buffer_t = ffi.metatype(ffi.typeof("buffer_t__byte_new"), mt)

-- buffer constructor

---@param size number
---@return ffi.cdata*
function byte.buffer(size)
	assert_numeric(size)
	assert(size > 0, "buffer size must be greater than zero")

	local pointer = ffi.C.malloc(size)
	assert(pointer ~= nil, "allocation error")

	local b = byte.buffer_t(pointer, size, 0)
	ffi.gc(b, b.free)

	_total = _total + size

	return b
end

assert(byte.to_signed(0x7F, 1) == 0x7F)
assert(byte.to_signed(0x7FFF, 2) == 0x7FFF)
assert(byte.to_signed(0x7FFFFFFF, 4) == 0x7FFFFFFF)
assert(byte.to_signed(0xFF, 1) == -1)
assert(byte.to_signed(0xFFFF, 2) == -1)
assert(byte.to_signed(0xFFFFFFFF, 4) == -1)

local b = byte.buffer(#types * 8)
ffi.fill(b.pointer, b.size, 0x80)

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

ffi.fill(b.pointer, b.size, 0x7F)
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
