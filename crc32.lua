local bit = require("bit")

local crc32_table = {}
for i = 1, 0x100 do
	local crc = i - 1
	for _ = 1, 8 do
		crc = bit.band(crc, 1) == 1 and bit.bxor(bit.rshift(crc, 1), 0xEDB88320) or bit.rshift(crc, 1)
	end
	crc32_table[i] = crc
end

local crc32 = {}

function crc32.hash(s)
	local crc = 0xFFFFFFFF
	for i = 1, s:len() do
		crc = bit.bxor(crc32_table[bit.band(bit.bxor(crc, s:byte(i)), 0xFF) + 1], bit.rshift(crc, 8))
	end
	return bit.bxor(crc, 0xFFFFFFFF)
end

return crc32
