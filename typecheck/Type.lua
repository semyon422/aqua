local class = require("class")

---@class typecheck.Type
---@field type string
---@operator call: typecheck.Type
local Type = class()

function Type:new(_type)
	self.type = _type
end

function Type:check(value)
	return type(value) == self.type
end

function Type.__tostring(t)
	return t.type
end

return Type
