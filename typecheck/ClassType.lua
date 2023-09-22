local Type = require("typecheck.Type")

---@class typecheck.ClassType: typecheck.Type
---@operator call: typecheck.ClassType
local ClassType = Type + {}

local class_by_name = {}
function ClassType.register_class(_type, T)
	class_by_name[_type] = T
end

function ClassType:new(name)
	self.name = name
end

function ClassType:check(value)
	local _type = class_by_name[self.name]
	if not _type then
		error("class " .. self.name .. " is not registered")
	end
	return _type * value or _type / value  -- todo: class<Class>
end

function ClassType.__tostring(t)
	return t.name
end

return ClassType
