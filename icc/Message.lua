local class = require("class")

---@class icc.Message
---@operator call: icc.Message
---@field [integer] any
local Message = class()

---@param id icc.EventId?
---@param ret true?
---@param ... any
function Message:new(id, ret, ...)
	self.id = id
	self.ret = ret
	self.n = select("#", ...)
	for i = 1, self.n do
		self[i] = select(i, ...)
	end
end

---@return any ...
function Message:unpack()
	return unpack(self, 1, self.n)
end

---@param value any
---@param pos integer?
function Message:insert(value, pos)
	if pos then
		table.insert(self, pos, value)
	else
		table.insert(self, value)
	end
	self.n = self.n + 1
end

return Message
