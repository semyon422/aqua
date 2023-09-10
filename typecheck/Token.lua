local class = require("class")

---@class typecheck.Token
---@field pos integer
---@field type string
---@field value string
---@operator call: typecheck.Token
local Token = class()

function Token:new(type, value, pos)
	self.type = type
	self.value = value
	self.pos = pos
end

function Token.__tostring(t)
	return ("%s %s %s"):format(t.pos, t.type, t.value)
end

return Token
