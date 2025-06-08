local ffi = require("ffi")
local bit = require("bit")

local leb128 = {}

-- https://en.wikipedia.org/wiki/LEB128

---@param p ffi.cdata*
---@return integer
---@return integer
function leb128.udec(p)
	p = ffi.cast("const unsigned char *", p) ---@type integer[]
	local result = 0ull
	local shift = 0
	local byte = 0

	local i = 0
	while true do
		byte = ffi.cast("uint64_t", p[i]) ---@cast byte integer
		i = i + 1
		result = bit.bor(result, bit.lshift(bit.band(byte, 0x7f), shift))
		if bit.band(byte, 0x80) == 0 then
			break
		end
		shift = shift + 7
	end

	return i, result
end

---@param p ffi.cdata*
---@return integer
---@return integer
function leb128.sdec(p)
	p = ffi.cast("const unsigned char *", p) ---@type integer[]
	local result = 0ll
	local shift = 0
	local byte = 0

	local i = 0
	while true do
		byte = ffi.cast("uint64_t", p[i]) ---@cast byte integer
		i = i + 1
		result = bit.bor(result, bit.lshift(bit.band(byte, 0x7f), shift))
		shift = shift + 7
		if bit.band(byte, 0x80) == 0 then
			break
		end
	end

	if shift < 64 and bit.band(byte, 0x40) ~= 0 then
		result = bit.bor(result, bit.lshift(bit.bnot(0ull), shift))
	end

	return i, ffi.cast("int64_t", result) ---@type integer, integer
end

---@param p ffi.cdata*
---@param value integer
function leb128.uenc(p, value)
	p = ffi.cast("unsigned char *", p) ---@type integer[]
	value = value + 0ull

	local i = 0

	while true do
		local byte = bit.band(value, 0x7f)
		value = bit.rshift(value, 7)
		if value ~= 0 then
			byte = bit.bor(byte, 0x80)
		end
		p[i] = byte
		i = i + 1
		if value == 0 then
			break
		end
	end

	return i
end

---@param p ffi.cdata*
---@param value integer
function leb128.senc(p, value)
	p = ffi.cast("unsigned char *", p) ---@type integer[]
	value = value + 0ll

	local i = 0

	local more = true
	while more do
		local byte = bit.band(value, 0x7f)
		value = bit.arshift(value, 7)
		if value == 0ll and bit.band(byte, 0x40) == 0ll or value == -1ll and bit.band(byte, 0x40) ~= 0ll then
			more = false
		else
			byte = bit.bor(byte, 0x80)
		end
		p[i] = byte
		i = i + 1
	end

	return i
end

-- tests

local p = ffi.new("uint8_t[?]", 16)

do -- from wikipedia
	local n = 624485
	local s = string.char(0xE5, 0x8E, 0x26) -- LSB to MSB

	local size = leb128.uenc(p, n)
	assert(size == #s)
	assert(ffi.string(p, size) == s)

	local size, result = leb128.udec(p)
	assert(size == 3)
	assert(result == n)
end

do -- from wikipedia
	local n = -123456
	local s = string.char(0xC0, 0xBB, 0x78) -- LSB to MSB

	local size = leb128.senc(p, n)
	assert(size == 3)
	assert(ffi.string(p, size) == s)

	local size, result = leb128.sdec(p)
	assert(size == 3)
	assert(result == n, result)
end

do
	local n = 0ull
	assert(tostring(n) == "0ULL")

	local size = leb128.uenc(p, n)
	assert(size == 1)

	local size, result = leb128.udec(p)
	assert(size == 1)
	assert(result == n)
end

do
	local n = -1ull
	assert(tostring(n) == "18446744073709551615ULL")

	local size = leb128.uenc(p, n)
	assert(size == 10)

	local size, result = leb128.udec(p)
	assert(size == 10)
	assert(result == n)
end

do
	local n = bit.ror(0ll, 1)
	assert(tostring(n) == "0LL")

	local size = leb128.uenc(p, n)
	assert(size == 1)

	local size, result = leb128.udec(p)
	assert(size == 1)
	assert(result == n)
end

do
	local n = bit.ror(1ll, 1)
	assert(tostring(n) == "-9223372036854775808LL")

	local size = leb128.uenc(p, n)
	assert(size == 10)

	local size, result = leb128.udec(p)
	assert(size == 10)
	assert(result == n)
end

do
	local n = bit.bnot(bit.ror(1ll, 1))
	assert(tostring(n) == "9223372036854775807LL")

	local size = leb128.uenc(p, n)
	assert(size == 9)

	local size, result = leb128.udec(p)
	assert(size == 9)
	assert(result == n)
end

return leb128
