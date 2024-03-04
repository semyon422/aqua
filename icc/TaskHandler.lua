local class = require("class")

---@class icc.TaskHandler
---@operator call: icc.TaskHandler
local TaskHandler = class()

TaskHandler.timeout = math.huge

---@param coder table
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

---@param peer table|userdata
---@param id number?
---@param ret boolean?
---@param ... any?
function TaskHandler:send(peer, id, ret, ...)
	peer:send(self.coder.encode({
		id = id,
		ret = ret,
		n = select("#", ...),
		...
	}))
end

---@param peer table
---@param ... any?
function TaskHandler:callnr(peer, ...)
	self:send(peer, nil, nil, ...)
end

---@param peer table
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

---@param peer table|userdata
---@param e table
---@param handler function
function TaskHandler:handle(peer, e, handler)
	if not e.id then
		handler(peer, unpack(e, 1, e.n))
		return
	end
	self:send(peer, e.id, true, handler(peer, unpack(e, 1, e.n)))
end
TaskHandler.handle = TaskHandler.wrap(TaskHandler.handle)

---@param data any
---@param peer table|userdata
---@param handler function
function TaskHandler:receive(data, peer, handler)
	local ok, e = pcall(self.coder.decode, data)
	if not ok or type(e) ~= "table" then
		return
	end

	if e.ret and self.tasks[e.id] then
		self.tasks[e.id](unpack(e, 1, e.n))
	else
		self:handle(peer, e, handler)
	end
end

return TaskHandler
