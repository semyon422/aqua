---@type love.data
local love_data = require("love.data")

local digest = {}

digest.module = "love.data"

---@param func digest.HashFunction
---@param s string
---@param hex boolean?
---@return string
function digest.hash(func, s, hex)
	local hash = love_data.hash(func, s)
	if not hex then
		return hash
	end
	return love_data.encode("string", "hex", hash) --[[@as string]]
end

return digest
