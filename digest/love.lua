---@type love.data
local love_data = require("love.data")

local digest = {}

digest.module = "love.data"

---@param func digest.HashFunction
---@param s string
---@param hex boolean?
---@return string
function digest.hash(func, s, hex)
	-- The configured LÖVE stubs still describe the pre-12 hash signature.
	---@diagnostic disable-next-line: redundant-parameter
	local hash = love_data.hash("string", func, s)
	if not hex then
		return hash
	end
	return love_data.encode("string", "hex", hash) --[[@as string]]
end

return digest
