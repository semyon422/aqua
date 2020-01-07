local bit = require('bit')
local ffi = require('ffi')

local byte = {}

byte.buffer = function(s, offset, length, step)
	local offset = offset or 0
	local length = length or #s
	return {
		string = s,
		length = length,
		pointer = ffi.cast("unsigned char*", s) + offset,
		step = step
	}
end

byte.slice = function(buffer, offset, length, step)
	return {
		string = buffer.string,
		length = length,
		pointer = buffer.pointer + offset,
		step = step
	}
end

byte.step = function(buffer, step)
	buffer.pointer = buffer.pointer + step
	buffer.length = buffer.length - step
end

byte.index = function(buffer, i)
	return tonumber(buffer.pointer[i - 1])
end

byte.tostring = function(buffer)
	return ffi.string(buffer.pointer, buffer.length)
end

byte.bytes = function(buffer)
	local bytes = {}
	local p = buffer.pointer
	for i = 1, buffer.length do
		bytes[i] = tonumber(p[i - 1])
	end
	return bytes
end

byte.read_string = function(buffer, length)
	local s = ffi.string(buffer.pointer, length)
	if buffer.step then byte.step(buffer, length) end
	return s
end

byte.read_uint8 = function(buffer)
	local number = byte.index(buffer, 1)
	if buffer.step then byte.step(buffer, 1) end
	return number
end

byte.read_int8 = function(buffer)
	local number = byte.read_uint8(buffer)
	return number < 0x80 and number or -0x100 + number
end

byte.read_uint16_le = function(buffer)
	local number = bit.lshift(byte.index(buffer, 2), 8) + byte.index(buffer, 1)
	if buffer.step then byte.step(buffer, 2) end
	return number
end

byte.read_uint16_be = function(buffer)
	local number = bit.lshift(byte.index(buffer, 1), 8) + byte.index(buffer, 2)
	if buffer.step then byte.step(buffer, 2) end
	return number
end

byte.read_int16_le = function(buffer)
	local number = byte.read_uint16_le(buffer)
	return number < 0x8000 and number or -0x10000 + number
end

byte.read_int16_be = function(buffer)
	local number = byte.read_uint16_be(buffer)
	return number < 0x8000 and number or -0x10000 + number
end

byte.read_uint32_le = function(buffer)
	local number
		= bit.lshift(byte.index(buffer, 4), 24)
		+ bit.lshift(byte.index(buffer, 3), 16)
		+ bit.lshift(byte.index(buffer, 2), 8)
		+            byte.index(buffer, 1)
	if buffer.step then byte.step(buffer, 4) end
	return number
end

byte.read_uint32_be = function(buffer)
	local number
		= bit.lshift(byte.index(buffer, 1), 24)
		+ bit.lshift(byte.index(buffer, 2), 16)
		+ bit.lshift(byte.index(buffer, 3), 8)
		+            byte.index(buffer, 4)
	if buffer.step then byte.step(buffer, 4) end
	return number
end

byte.read_int32_le = function(buffer)
	local number = byte.read_uint32_le(buffer)
	return number < 0x8000 and number or -0x10000 + number
end

byte.read_int32_be = function(buffer)
	local number = byte.read_uint32_be(buffer)
	return number < 0x8000 and number or -0x10000 + number
end

byte.read_float_le = function(buffer)
	return byte.int32_to_float_le(byte.read_uint32_le(buffer))
end

byte.read_float_be = function(buffer)
	return byte.int32_to_float_be(byte.read_uint32_be(buffer))
end

byte.int32_to_float_le = function(number)
	local sign = bit.rshift(number, 31) == 1 and -1 or 1
	local exponent = bit.band(bit.rshift(number, 23), 0xFF)
	local mantissa = exponent ~= 0 and bit.bor(bit.band(number, 0x7FFFFF), 0x800000) or bit.lshift(bit.band(number, 0x7FFFFF), 1)
	
	return sign * (mantissa * 2 ^ -23) * (2 ^ (exponent - 127))
end

byte.int32_to_float_be = function(number)
	local sign = bit.rshift(number, 31) == 1 and -1 or 1
	local exponent = bit.band(bit.rshift(number, 23), 0xFF)
	local mantissa = exponent ~= 0 and bit.bor(bit.band(number, 0x7FFFFF), 0x800000) or bit.lshift(bit.band(number, 0x7FFFFF), 1)
	
	return sign * (mantissa * 2 ^ -23) * (2 ^ (exponent - 127))
end

local b = byte.buffer("qwertyuiop")
assert(b.length == 10)
assert(byte.tostring(byte.slice(b, 2, 2)) == "er")
do
	local bytes = byte.bytes(b)
	assert(bytes[1] == 113) -- q
	assert(bytes[10] == 112) -- p
end
do
	local s = string.char(0, 0, 0, 0xf)
	assert(#s == 4)
	local b = byte.buffer(s, 0, #s, true)
	assert(b.length == 4)
	assert(byte.read_uint32_be(b) == 0xf)
	assert(b.length == 0)
end
do
	local s = string.char(0, 0xf)
	assert(#s == 2)
	local b = byte.buffer(s)
	assert(byte.read_uint16_be(b) == 0x000f)
	assert(byte.read_uint16_le(b) == 0x0f00)
end
do
	local a = 0x3e200000
	local b = tonumber("00111110001000000000000000000000", 2)
	assert(a == b)
	assert(byte.int32_to_float_be(a) == 0.15625)
	assert(byte.int32_to_float_be(0x3f800000) == 1)
end

return byte
