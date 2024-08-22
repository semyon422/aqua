local class = require("class")

---@alias icc.EventId integer
---@alias icc.Handler fun(peer: icc.IPeer, ...: any): ...: any

---@class icc.TaskHandler
---@operator call: icc.TaskHandler
---@field timeouts {[icc.EventId]: integer}
---@field tasks {[icc.EventId]: function}
---@field event_id icc.EventId
local TaskHandler = class()

TaskHandler.timeout = math.huge

---@param coder icc.ICoder
function TaskHandler:new(coder)
	self.coder = coder
	self.timeouts = {}
	self.tasks = {}
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
	peer:send(self.coder:encode({
		id = id,
		ret = ret,
		n = select("#", ...),
		...
	}))
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
	self.tasks[id] = function(...)
		self.tasks[id] = nil
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
			self.tasks[id](nil, "timeout")
		end
	end
end

---@param peer icc.IPeer
---@param msg icc.Message
---@param handler icc.Handler
function TaskHandler:handle(peer, msg, handler)
	if not msg.id then
		handler(peer, msg:unpack())
		return
	end
	self:send(peer, msg.id, true, handler(peer, msg:unpack()))
end
TaskHandler.handle = TaskHandler.wrap(TaskHandler.handle)

---@param data any
---@param peer icc.IPeer
---@param handler icc.Handler
function TaskHandler:receive(data, peer, handler)
	local ok, msg = pcall(self.coder.decode, self.coder, data)
	if not ok or type(msg) ~= "table" then
		return
	end
	---@cast msg icc.Message

	if msg.ret and self.tasks[msg.id] then
		self.tasks[msg.id](msg:unpack())
	else
		self:handle(peer, msg, handler)
	end
end

return TaskHandler
