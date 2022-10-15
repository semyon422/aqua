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

thread.unload = function()
	return ThreadPool:unload()
end

thread.waitAsync = function()
	return ThreadPool:waitAsync()
end

thread.update = function()
	for c in pairs(thread.coroutines) do
		if coroutine.status(c) == "dead" then
			thread.current = thread.current - 1
			thread.coroutines[c] = nil
		end
	end
	return ThreadPool:update()
end

local pushedTask
thread.pushTask = function(task)
	pushedTask = task
end

local runThread = function(f, params, callback)
	local task = {
		f = f,
		params = params,
		result = callback,
		error = error,
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

local run = function(f, ...)
	local c = coroutine.running()
	if not c then
		error("attempt to yield from outside a coroutine")
	end
	runThread(f, {...}, function(...)
		assert(coroutine.resume(c, ...))
	end)
	return coroutine.yield()
end

local call = function(f, ...)
	-- assert(not coroutine.running(), "attempt to call a function from a coroutine")
	-- return coroutine.wrap(f)(...)
	thread.total = thread.total + 1
	thread.current = thread.current + 1
	local c = coroutine.create(function(...)
		assert(xpcall(f, debug.traceback, ...))
	end)
	coroutine.resume(c, ...)
	thread.coroutines[c] = true
	return c
end

thread.run = runThread

thread.async = function(f)
	return function(...)
		return run(f, ...)
	end
end

thread.coro = function(f)
	return function(...)
		return call(f, ...)
	end
end

return thread
