---@type {new: fun(_: string?): {final: fun(_: any, s: string): string}}
local openssl_digest = require("openssl.digest")

-- https://25thandclement.com/~william/projects/luaossl.pdf

local digest = {}

digest.module = "openssl.digest"

---@param func digest.HashFunction
---@param s string
---@return string
function digest.hash(func, s)
	return openssl_digest.new(func):final(s)
end

return digest
