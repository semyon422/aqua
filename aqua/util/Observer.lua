local Observer = {}

Observer.new = function(self)
	local observer = {}
	
	setmetatable(observer, self)
	self.__index = self
	
	return observer
end

Observer.receiveEvent = function(self, event) end

return Observer