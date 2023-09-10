local Type = require("typecheck.Type")

---@class typecheck.UnionType: typecheck.Type
---@field is_optional boolean
---@operator call: typecheck.UnionType
local UnionType = Type + {}

function UnionType:check(value)
	if value == nil and self.is_optional then
		return true
	end
	for _, _type in ipairs(self) do
		if _type:check(value) then
			return true
		end
	end
	return false
end

function UnionType.__tostring(t)
	local out = {}
	for i, v in ipairs(t) do
		out[i] = tostring(v)
	end
	local s = table.concat(out, "|")
	if t.is_optional then
		s = s .. "?"
	end
	return s
end

return UnionType
