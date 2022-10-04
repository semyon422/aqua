local delay = {}

local timers = {}
local waiters = {}

delay.update = function()
	local time = love.timer.getTime()
	for c, endTime in pairs(timers) do
		if endTime <= time then
			timers[c] = nil
			assert(coroutine.resume(c, time))
		end
	end
	for c, func in pairs(waiters) do
		if func() then
			waiters[c] = nil
			assert(coroutine.resume(c))
		end
	end
end

delay.sleep = function(duration)
	local c = coroutine.running()
	if not c then
		error("attempt to yield from outside a coroutine")
	end
	timers[c] = love.timer.getTime() + duration
	return coroutine.yield()
end

delay.wait = function(func)
	local c = coroutine.running()
	if not c then
		error("attempt to yield from outside a coroutine")
	end
	waiters[c] = func
	return coroutine.yield()
end

delay.debounce = function(object, key, duration, func, ...)
	local time = love.timer.getTime()
	local c = object[key]
	if c then
		if not timers[c] then
			return
		end
		timers[c] = time + duration
		return
	end

	local q, w, e, r, t, y, u, i = ...
	c = coroutine.create(function()
		delay.sleep(duration)
		func(q, w, e, r, t, y, u, i)
		object[key] = nil
	end)
	object[key] = c
	assert(coroutine.resume(c))
	return function()
		timers[c] = nil
		object[key] = nil
	end
end

delay.every = function(interval, func, ...)
	assert(type(func) == "function", "func function must be a function")
	assert(type(interval) == "number", "interval must be a number")
	local stop = false
	coroutine.wrap(function(...)
		local ptime = love.timer.getTime()
		local time = ptime
		while true do
			ptime = math.max(ptime + interval, time)
			time = delay.sleep(ptime - time)
			if stop or func(...) then
				return
			end
		end
	end)(...)
	return function()
		stop = true
	end
end

return delay
