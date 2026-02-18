local IQueue = require("icc.IQueue")
local StringBufferPeer = require("icc.StringBufferPeer")

---@class icc.SharedMemoryQueue: icc.IQueue
---@operator call: icc.SharedMemoryQueue
local SharedMemoryQueue = IQueue + {}

local peer = StringBufferPeer()

---@param dict web.ISharedDict
---@param key string
function SharedMemoryQueue:new(dict, key)
	self.dict = dict
	self.key = key
end

---@param msg icc.Message
function SharedMemoryQueue:push(msg)
	local s = peer:encode(msg)
	self.dict:lpush(self.key, s)
end

---@return icc.Message?
function SharedMemoryQueue:pop()
	local s = self.dict:rpop(self.key)
	if not s then
		return
	end
	---@cast s -number
	return peer:decode(s)
end

---@return integer
function SharedMemoryQueue:count()
	return self.dict:llen(self.key) or 0
end

return SharedMemoryQueue
