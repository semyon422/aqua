local Class = {}

Class.new = function(self, object, ...)
	object = object or {}

	local construct = object.construct
	object.construct = nil

	setmetatable(object, self)
	self.__index = self

	if construct ~= false and object.construct and object.construct ~= Class.construct then
		object:construct(...)
	end

	return object
end

Class.construct = function() end

return Class
