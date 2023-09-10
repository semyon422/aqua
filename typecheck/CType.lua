local Type = require("typecheck.Type")

---@class typecheck.CType: typecheck.Type
---@operator call: typecheck.CType
local CType = Type + {}

function CType:new(name)
	self.name = name
end

function CType:check(value)
	local t = type(value)
	return t == "userdata" or t == "cdata"
end

function CType.__tostring(t)
	return t.name
end

return CType
