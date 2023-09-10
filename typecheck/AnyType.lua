local Type = require("typecheck.Type")

---@class typecheck.AnyType: typecheck.Type
---@operator call: typecheck.AnyType
local AnyType = Type + {}

function AnyType:check(value)
	return value ~= nil
end

function AnyType.__tostring()
	return "any"
end

return AnyType
