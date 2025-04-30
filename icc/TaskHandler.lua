local class = require("class")
local icc_co = require("icc.co")
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

---@param ok boolean
---@param ... any
---@return any ...
local function assert_pcall(ok, ...)
	if not ok then
		local level = 2
		error(debug.traceback(..., level), level)
	end
	return ...
end

---@param peer icc.IPeer
---@param id icc.EventId?
---@param ret true?
---@param ... any?
function TaskHandler:send(peer, id, ret, ...)
	local bytes, err = peer:send(Message(id, ret, ...))
	if not bytes then
		local level = 3
		if err == nil then
			err = "missing send error"
		end
		error(debug.traceback(err, level), level)
	end
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
	self.callbacks[id] = function(ret, ...)
		self.callbacks[id] = nil
		self.timeouts[id] = nil

		---@type boolean, any
		local ok, err
		if not ret then -- timeout
			ok, err = coroutine.resume(c, ret, ...)
		else
			ok, err = coroutine.resume(c, ...)
		end

		if not ok then
			error(err .. "\n" .. trace)
		end
	end

	return assert_pcall(coroutine.yield())
end

function TaskHandler:update()
	local time = os.time()
	for id, t in pairs(self.timeouts) do
		if t <= time then
			self.callbacks[id](false, "timeout")
		end
	end
end

---@param peer icc.IPeer
---@param msg icc.Message
function TaskHandler:handleCall(peer, msg)
	local handler = self.handler
	if not msg.id then
		handler:handle(self, peer, msg:unpack())
		return
	end
	self:send(peer, msg.id, true, xpcall(handler.handle, debug.traceback, handler, self, peer, msg:unpack()))
end
TaskHandler.handleCall = icc_co.wrap(TaskHandler.handleCall)

---@param msg icc.Message
function TaskHandler:handleReturn(msg)
	assert(msg.ret)
	self.callbacks[msg.id](true, msg:unpack())
end

return TaskHandler
