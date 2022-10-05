local Class = {}

Class.extend = function(self, object)
	self.__index = self
	return setmetatable(object or {}, self)
end

Class.new = function(self, object)
	object = self:extend(object)
	object:construct()
	return object
end

Class.construct = function() end

return Class
