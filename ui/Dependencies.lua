local class = require("class")

---@class ui.Dependencies
---@operator call: ui.Dependencies
---@field private deps {[table]: any}
local Dependencies = class()

function Dependencies:new()
	self.deps = {}
end

---@param _type table
---@param object any
function Dependencies:add(_type, object)
	if not (_type * object) then
		error("Incorrect type")
	end

	self.deps[_type] = object
end

---@generic T
---@param _type T
---@return T
function Dependencies:get(_type)
	local object = self.deps[_type]
	if not object then
		error("Dependency doesn't exist")
	end
	return object
end

return Dependencies
