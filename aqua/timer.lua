local timer = {}

local timers = {}
local waiters = {}

timer.update = function()
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

timer.sleep = function(duration)
	local c = coroutine.running()
	if not c then
		error("attempt to yield from outside a coroutine")
	end
	timers[c] = love.timer.getTime() + duration
	return coroutine.yield()
end

timer.wait = function(func)
	local c = coroutine.running()
	if not c then
		error("attempt to yield from outside a coroutine")
	end
	waiters[c] = func
	return coroutine.yield()
end

timer.debounce = function(object, key, duration, func, ...)
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
		timer.sleep(duration)
		func(q, w, e, r, t, y, u, i)
		object[key] = nil
	end)
	object[key] = c
	coroutine.resume(c)
end

return timer
