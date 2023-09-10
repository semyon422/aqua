local Type = require("typecheck.Type")

---@class typecheck.ArrayType: typecheck.Type
---@field type typecheck.Type
---@operator call: typecheck.ArrayType
local ArrayType = Type + {}

function ArrayType:check(value)
	return not value[1] or self.type:check(value[1])
end

function ArrayType.__tostring(t)
	return "[]" .. tostring(t.type)
end

return ArrayType
