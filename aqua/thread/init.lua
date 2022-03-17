local thread = {}

thread.Thread = require("aqua.thread.Thread")
thread.ThreadPool = require("aqua.thread.ThreadPool")

local runThread = function(f, params, callback)
	return thread.ThreadPool:execute({
		f = f,
		params = params,
		result = callback,
		error = error,
		trace = debug.traceback(),
	})
end

local run = function(f, ...)
	local c = coroutine.running()
	if not c then
		error("attempt to yield from outside a coroutine")
	end
	local q, w, e, r, t, y, u, i
	runThread(f, {...}, function(...)
		q, w, e, r, t, y, u, i = ...
		assert(coroutine.resume(c))
	end)
	coroutine.yield()
	return q, w, e, r, t, y, u, i
end

local call = function(f, ...)
	if not coroutine.running() then
		return coroutine.wrap(f)(...)
	end
	return f(...)
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
