local class = require("class")
local ContextQueuePeer = require("icc.ContextQueuePeer")
local Message = require("icc.Message")

---@class icc.Queues
---@operator call: icc.Queues
local Queues = class()

---@param queue_factory fun(id: string): icc.IQueue
function Queues:new(queue_factory)
	self.queue_factory = queue_factory
end

---@param id string
function Queues:getQueue(id)
	return self.queue_factory(id)
end

---@param rid string
---@param sid string
---@return icc.IPeer receiver_peer
function Queues:getPeer(rid, sid)
	return ContextQueuePeer(self:getQueue(rid), sid)
end

---@param rid string
---@return icc.Message?
---@return icc.IPeer? sender_peer
function Queues:pop(rid)
	local queue = self:getQueue(rid)
	---@type icc.PackedMessage?
	local pmsg = queue:pop()
	if not pmsg then
		return
	end
	return setmetatable(pmsg.msg, Message), pmsg.sid and self:getPeer(pmsg.sid, rid)
end

---@param id string
function Queues:count(id)
	return self:getQueue(id):count()
end

return Queues
