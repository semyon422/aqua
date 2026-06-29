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

---@class thread.Future
---@field done boolean
---@field waiting thread?
---@field result any[]?

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

---@param f function
---@param argsf function
function thread.setInitFunc(f, argsf)
	ThreadPool:setInitFunc(f, argsf)
end

function thread.stopThreads()
	ThreadPool:stopThreads()
end

---@param f function
---@return string
local function getFunctionName(f)
	local info = debug.getinfo(f, "Sl")
	return ("%s:%s"):format(info.short_src or info.source or "unknown", info.linedefined or "?")
end

---@param f function|string
---@param args table
---@param callback function
---@param name string?
---@return boolean?
local function runThread(f, args, callback, name)
	if type(f) == "function" then
		name = name or getFunctionName(f)
		f = string.dump(f)
	end
	local task = {
		f = f,
		args = args,
		result = callback,
		trace = debug.traceback(),
		name = name or "thread task",
	}
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

---@param f function|string
---@param ... any?
---@return thread.Future
local function start(f, ...)
	---@type thread.Future
	local future = {
		done = false,
	}
	local args = {n = select("#", ...), ...}
	runThread(f, args, function(...)
		future.done = true
		future.result = {n = select("#", ...), ...}
		if future.waiting then
			assert(coroutine.resume(future.waiting))
		end
	end)
	return future
end

---@param future thread.Future
---@return any?...
function thread.wait(future)
	if not future.done then
		future.waiting = coroutine.running()
		coroutine.yield()
		future.waiting = nil
	end
	local result = assert(future.result)
	return unpack(result, 1, result.n)
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

---@param f function|string
---@return fun(...: any?): thread.Future
function thread.future(f)
	return function(...)
		return start(f, ...)
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
