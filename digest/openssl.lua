---@type {new: fun(_: string?): {final: fun(_: any, s: string): string}}
local openssl_digest = require("openssl.digest")

-- https://25thandclement.com/~william/projects/luaossl.pdf

local digest = {}

digest.module = "openssl.digest"

---@param c string
---@return string
local function fhex(c)
	return ("%02x"):format(c:byte())
end

---@param s string
---@return string
local function tohex(s)
	return (s:gsub('.', fhex))
end

---@param func digest.HashFunction
---@param s string
---@param hex boolean?
---@return string
function digest.hash(func, s, hex)
	local hash = openssl_digest.new(func):final(s)
	if not hex then
		return hash
	end
	return tohex(hash)
end

return digest
