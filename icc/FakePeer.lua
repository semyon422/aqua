local IPeer = require("icc.IPeer")

---@class icc.FakePeer: icc.IPeer
---@operator call: icc.FakePeer
local FakePeer = IPeer + {}

function FakePeer:new()
	---@type any[]
	self.messages = {}
end

---@param data any
function FakePeer:send(data)
	table.insert(self.messages, data)
end

---@return integer
function FakePeer:count()
	return #self.messages
end

---@param i any
---@return any
function FakePeer:get(i)
	return self.messages[i]
end

return FakePeer
