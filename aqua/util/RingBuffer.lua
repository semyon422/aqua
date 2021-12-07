local Class = require("aqua.util.Class")

local RingBuffer = Class:new()

RingBuffer.construct = function(self)
	self.size = self.size or 1
	self.index = 1
	for i = 1, self.size do
		self[i] = 0
	end
end

RingBuffer.write = function(self, value)
	self[self.index] = value
	self.index = self.index % self.size + 1
end

RingBuffer.read = function(self)
	local value = self[self.index]
	self.index = self.index % self.size + 1
	return value
end

return RingBuffer
