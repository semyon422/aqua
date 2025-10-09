local class = require("class")

---@class ui.Context
---@operator call: ui.Context
---@field private objects {[table]: any}
local Context = class()

function Context:new()
	self.objects = {}
end

---@param _type table
---@param object any
function Context:add(_type, object)
	if not (_type * object) then
		error("Incorrect type")
	end

	self.objects[_type] = object
end

---@generic T
---@param _type T
---@return T
function Context:get(_type)
	local object = self.objects[_type]
	if not object then
		error("Instance of this type doesn't exist")
	end
	return object
end

return Context
