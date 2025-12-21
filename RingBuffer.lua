local class = require("class")

---@class util.RingBuffer
---@operator call: util.RingBuffer
---@field [integer] any
local RingBuffer = class()

---@param size number
function RingBuffer:new(size)
	self.size = math.max(size or 1, 1)
	self.index = 1
	for i = 1, self.size do
		self[i] = 0
	end
end

---@param value any?
function RingBuffer:write(value)
	self[self.index] = value
	self.index = self.index % self.size + 1
end

---@return any|nil
function RingBuffer:read()
	local value = self[self.index]
	self.index = self.index % self.size + 1
	return value
end

return RingBuffer
