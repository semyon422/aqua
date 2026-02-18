local IPeer = require("icc.IPeer")
local PackedMessage = require("icc.PackedMessage")

---@class icc.ContextQueuePeer: icc.IPeer
---@field queue icc.IQueue target queue
---@field sid any sender id
local ContextQueuePeer = IPeer + {}

---@param queue icc.IQueue target queue
---@param sid any sender id
function ContextQueuePeer:new(queue, sid)
	self.queue = queue
	self.sid = sid
end

---@param msg icc.Message
---@return integer?
---@return string?
function ContextQueuePeer:send(msg)
	self.queue:push(PackedMessage(msg, not msg.ret and self.sid or nil))
	return 1
end

function ContextQueuePeer:close()
end

return ContextQueuePeer
