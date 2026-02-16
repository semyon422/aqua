local IPeer = require("icc.IPeer")
local Queue = require("icc.Queue")

---@class icc.QueuePeer: icc.IPeer
---@operator call: icc.QueuePeer
local QueuePeer = IPeer + {}

---@param queue icc.IQueue?
function QueuePeer:new(queue)
	self.queue = queue or Queue()
end

---@param queue icc.IQueue
function QueuePeer:setQueue(queue)
	self.queue = queue
end

---@param msg icc.Message
---@return integer?
---@return string?
function QueuePeer:send(msg)
	self.queue:push(msg)
	return 1
end

---@return integer
function QueuePeer:count()
	return self.queue:count()
end

---@param i integer
---@return icc.Message
function QueuePeer:get(i)
	-- This relies on the internal implementation of Queue
	---@cast self {queue: icc.Queue}
	return self.queue.messages[i]
end

function QueuePeer:close()
end

return QueuePeer
