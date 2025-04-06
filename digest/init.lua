local digest = {}

---@alias digest.HashFunction
---| "md5"
---| "sha1"
---| "sha224"
---| "sha256"
---| "sha384"
---| "sha512"

if pcall(require, "love.data") then
	return require("digest.love")
end

if pcall(require, "openssl.digest") then
	return require("digest.openssl")
end

digest.module = "digest"

---@param func digest.HashFunction
---@param s string
---@return string
function digest.hash(func, s)
	error("not implemented")
end

return digest
