local IQueue = require("icc.IQueue")

---@class icc.Queue: icc.IQueue
---@operator call: icc.Queue
local Queue = IQueue + {}

function Queue:new()
	self.messages = {}
end

function Queue:push(msg)
	table.insert(self.messages, msg)
end

function Queue:pop()
	return table.remove(self.messages, 1)
end

function Queue:count()
	return #self.messages
end

return Queue
