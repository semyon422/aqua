local thread = {}

thread.Thread = require("aqua.thread.Thread")
thread.ThreadPool = require("aqua.thread.ThreadPool")

local runThread = function(f, params, callback)
    return thread.ThreadPool:execute({
        f = f,
        params = params,
        result = callback,
        error = error,
    })
end

local run = function(f, params, callback)
	local c = coroutine.running()
	if not c or callback then
		return runThread(f, params, callback)
	end
	local response
	runThread(f, params, function(res)
		response = res
		coroutine.resume(c)
	end)
	coroutine.yield()
	return response
end

thread.run = runThread

thread.async = function(f)
	return function(params, callback)
        return run(f, params, callback)
    end
end

thread.call = function(f)
	return coroutine.wrap(f)()
end

return thread
