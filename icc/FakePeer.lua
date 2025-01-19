local IPeer = require("icc.IPeer")

---@class icc.FakePeer: icc.IPeer
---@operator call: icc.FakePeer
local FakePeer = IPeer + {}

function FakePeer:new()
	---@type icc.Message[]
	self.messages = {}
end

---@param msg icc.Message
function FakePeer:send(msg)
	table.insert(self.messages, msg)
end

---@return integer
function FakePeer:count()
	return #self.messages
end

---@param i integer
---@return icc.Message
function FakePeer:get(i)
	return self.messages[i]
end

return FakePeer
