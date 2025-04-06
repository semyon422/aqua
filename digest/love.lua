---@type love.data
local love_data = require("love.data")

local digest = {}

digest.module = "love.data"

---@param func digest.HashFunction
---@param s string
---@return string
function digest.hash(func, s)
	return love_data.hash(func, s)
end

return digest
