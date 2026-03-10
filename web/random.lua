local ffi = require("ffi")

local random = {}

random.module = "web.random"

-- TODO: CSPRNG

---@param size integer
---@return string
function random.bytes(size)
	---@type integer[]
	local p = ffi.new("uint8_t[?]", size)
	for i = 1, size do
		p[i - 1] = math.random(size)
	end
	return ffi.string(p, size)
end

---@param size integer
---@return string
function random.hex(size)
	local bytes = random.bytes(size / 2)
	---@type string[]
	local buf = {}
	for i = 1, #bytes do
		table.insert(buf, ("%02x"):format(bytes:byte(i)))
	end
	return table.concat(buf)
end

---@type boolean, {bytes: fun(size: integer): string}
local ok, openssl_rand = pcall(require, "openssl.rand")
if ok then
	random.module = "openssl.rand"
	rawset(random, "bytes", openssl_rand.bytes)
	-- random.bytes = openssl_rand.bytes
end

return random
