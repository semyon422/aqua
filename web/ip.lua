local bit = require("bit")
local ffi = require("ffi")

---@param x integer
---@param n integer
---@return integer
local function ls(x, n)
	return bit.lshift(bit.band(x, 0xFF), n)
end

---@param x integer
---@param n integer
---@return integer
local function rs(x, n)
	return bit.band(bit.rshift(x, n), 0xFF)
end

local ip = {}

function ip.decode(n)
	if type(n) ~= "number" then n = 0 end
	return ("%s.%s.%s.%s"):format(rs(n, 24), rs(n, 16), rs(n, 8), rs(n, 0))
end

---@type {[0]: integer}
local int32_p = ffi.new("int32_t[1]")
local uint32_p = ffi.cast("uint32_t*", int32_p)

function ip.encode(s)
	---@type string, string, string, string
	local a, b, c, d = s:match("^(%d?%d?%d)%.(%d?%d?%d)%.(%d?%d?%d)%.(%d?%d?%d)$")
	a, b, c, d = tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0, tonumber(d) or 0
	local n = bit.bor(ls(a, 24), ls(b, 16), ls(c, 8), ls(d, 0))
	int32_p[0] = n
	return uint32_p[0]
end

return ip
