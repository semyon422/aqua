local class = require("class")

local RingBuffer = class()

function RingBuffer:new(size)
	self.size = math.max(size or 1, 1)
	self.index = 1
	for i = 1, self.size do
		self[i] = 0
	end
end

function RingBuffer:write(value)
	self[self.index] = value
	self.index = self.index % self.size + 1
end

function RingBuffer:read()
	local value = self[self.index]
	self.index = self.index % self.size + 1
	return value
end

return RingBuffer
