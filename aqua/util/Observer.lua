local Observer = {}

Observer.new = function(self)
	local observer = {}
	
	setmetatable(observer, self)
	self.__index = self
	
	return observer
end

Observer.receive = function(self, event) end

return Observer