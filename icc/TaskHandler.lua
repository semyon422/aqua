local class = require("class")
local icc_co = require("icc.co")
local Message = require("icc.Message")

---@alias icc.EventId integer

---@class icc.TaskHandler
---@operator call: icc.TaskHandler
---@field timeouts {[icc.EventId]: integer}
---@field callbacks {[icc.EventId]: fun(...: any)?}
---@field event_id icc.EventId
local TaskHandler = class()

TaskHandler.timeout = math.huge

---@param handler icc.IHandler
---@param name string?
function TaskHandler:new(handler, name)
	self.handler = handler
	self.name = name or "icc"
	self.timeouts = {}
	self.callbacks = {}
	self.event_id = 0
	self.bytes_sent = 0
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
		error(debug.traceback(("[%s] %s"):format(self.name, tostring(err)), level), level)
	end
	self.bytes_sent = self.bytes_sent + bytes
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
			error(err .. "\n[local callback] " .. trace)
		end
	end

	return icc_co.assert_pcall(coroutine.yield())
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
---@param ctx icc.IPeerContext
---@param msg icc.Message
function TaskHandler:handle(peer, ctx, msg)
	if msg.ret then
		self:handleReturn(msg)
	else
		self:handleCall(peer, ctx, msg)
	end
	self:update()
end

---@param peer icc.IPeer
---@param ctx icc.IPeerContext
---@param msg icc.Message
function TaskHandler:handleCall(peer, ctx, msg)
	local handler = self.handler
	if not msg.id then
		local ok, err = xpcall(handler.handle, debug.traceback, handler, ctx, msg:unpack())
		if not ok then
			error(("[%s] no-return call error: %s"):format(self.name, tostring(err)))
		end
		return
	end
	self:send(peer, msg.id, true, xpcall(handler.handle, function(err)
		return debug.traceback(("[%s] %s"):format(self.name, tostring(err)), 2)
	end, handler, ctx, msg:unpack()))
end
TaskHandler.handleCall = icc_co.callwrap(TaskHandler.handleCall)

---@param msg icc.Message
function TaskHandler:handleReturn(msg)
	assert(msg.ret)
	local id = msg.id
	---@cast id -?
	local cb = self.callbacks[id]
	if cb then -- Timeouts, Cancellations/Resets
		cb(true, msg:unpack())
	end
end

return TaskHandler
