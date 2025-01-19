local class = require("class")
local Message = require("icc.Message")

---@alias icc.EventId integer

---@class icc.TaskHandler
---@operator call: icc.TaskHandler
---@field timeouts {[icc.EventId]: integer}
---@field callbacks {[icc.EventId]: fun(...: any)}
---@field event_id icc.EventId
local TaskHandler = class()

TaskHandler.timeout = math.huge

---@param handler icc.IHandler
function TaskHandler:new(handler)
	self.handler = handler
	self.timeouts = {}
	self.callbacks = {}
	self.event_id = 0
end

---@param f function
---@return function
local function wrap(f)
	return function(...)
		return coroutine.wrap(f)(...)
	end
end
TaskHandler.wrap = wrap

---@param peer icc.IPeer
---@param id icc.EventId?
---@param ret true?
---@param ... any?
function TaskHandler:send(peer, id, ret, ...)
	peer:send(Message(id, ret, ...))
end

---@param peer icc.IPeer
---@param ... any?
function TaskHandler:callnr(peer, ...)
	self:send(peer, nil, nil, ...)
end

---@param peer icc.IPeer
---@param ... any?
---@return any?...
function TaskHandler:call(peer, ...)
	local c = coroutine.running()
	if not c then
		error("attempt to yield from outside a coroutine")
	end

	self.event_id = self.event_id + 1
	local id = self.event_id

	self:send(peer, id, nil, ...)

	local trace = debug.traceback(c)
	self.timeouts[id] = os.time() + self.timeout
	self.callbacks[id] = function(...)
		self.callbacks[id] = nil
		self.timeouts[id] = nil
		local status, err = coroutine.resume(c, ...)
		if not status then
			error(err .. "\n" .. trace)
		end
	end

	return coroutine.yield()
end

function TaskHandler:update()
	local time = os.time()
	for id, t in pairs(self.timeouts) do
		if t <= time then
			self.callbacks[id](nil, "timeout")
		end
	end
end

---@param peer icc.IPeer
---@param msg icc.Message
function TaskHandler:handle(peer, msg)
	if not msg.id then
		self.handler:handle(self, peer, msg:unpack())
		return
	end
	self:send(peer, msg.id, true, self.handler:handle(self, peer, msg:unpack()))
end
TaskHandler.handle = TaskHandler.wrap(TaskHandler.handle)

---@param msg icc.Message
function TaskHandler:handleReturn(msg)
	assert(msg.ret)
	self.callbacks[msg.id](msg:unpack())
end

return TaskHandler
