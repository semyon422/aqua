local thread = {}

local Thread = require("thread.Thread")
local ThreadPool = require("thread.ThreadPool")
thread.Thread = Thread
thread.ThreadPool = ThreadPool

thread.shared = ThreadPool.synctable

thread.unload = function()
	return ThreadPool:unload()
end

thread.waitAsync = function()
	return ThreadPool:waitAsync()
end

thread.update = function()
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
	return coroutine.wrap(function(...)
		assert(xpcall(f, debug.traceback, ...))
	end)(...)
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
