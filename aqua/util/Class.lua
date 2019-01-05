local Class = {}

Class.new = function(self, object, ...)
	local object = object or {}
	
	setmetatable(object, self)
	self.__index = self
	object.base = self
	
	if object.construct then
		object:construct(...)
	end
	
	return object
end

return Class
