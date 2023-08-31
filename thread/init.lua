assert(arg, "Allowed only in the main thread")

local thread = {}

local Thread = require("thread.Thread")
local ThreadPool = require("thread.ThreadPool")
thread.Thread = Thread
thread.ThreadPool = ThreadPool

thread.shared = ThreadPool.synctable

thread.coroutines = {}
thread.total = 0
thread.current = 0

function thread.unload()
	return ThreadPool:unload()
end

function thread.waitAsync()
	return ThreadPool:waitAsync()
end

function thread.update()
	for c in pairs(thread.coroutines) do
		if coroutine.status(c) == "dead" then
			thread.current = thread.current - 1
			thread.coroutines[c] = nil
		end
	end
	return ThreadPool:update()
end

local pushedTask

---@param task table
function thread.pushTask(task)
	pushedTask = task
end

---@param f function|string
---@param args table
---@param callback function
---@return boolean?
local function runThread(f, args, callback)
	if type(f) == "function" then
		f = string.dump(f)
	end
	local task = {
		f = f,
		args = args,
		result = callback,
		trace = debug.traceback(),
	}
	if pushedTask then
		for k, v in pairs(pushedTask) do
			task[k] = v
		end
		pushedTask = nil
	end
	return thread.ThreadPool:execute(task)
end

---@param f function|string
---@param ... any?
---@return any?...
local function run(f, ...)
	local c = assert(coroutine.running(), "attempt to yield from outside a coroutine")
	local args = {n = select("#", ...), ...}
	runThread(f, args, function(...)
		assert(coroutine.resume(c, ...))
	end)
	return coroutine.yield()
end

---@param f function
---@param ... any?
---@return thread
local function call(f, ...)
	-- assert(not coroutine.running(), "attempt to call a function from a coroutine")
	-- return coroutine.wrap(f)(...)
	thread.total = thread.total + 1
	thread.current = thread.current + 1
	local c = coroutine.create(function(...)
		assert(xpcall(f, debug.traceback, ...))
	end)
	assert(coroutine.resume(c, ...))
	thread.coroutines[c] = true
	return c
end

---@param f function|string
---@return function
function thread.async(f)
	return function(...)
		return run(f, ...)
	end
end

---@param f function
---@return function
function thread.coro(f)
	return function(...)
		return call(f, ...)
	end
end

return thread
