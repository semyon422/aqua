local delay = {}

local timers = {}
local waiters = {}

---@type function
local get_time

---@param f function|table
function delay.set_timer(f)
	if type(f) == "function" then
		get_time = f
		return
	end
	function get_time()
		return f[1]
	end
end

function delay.update()
	local time = get_time()
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

---@param duration number
---@return number
function delay.sleep(duration)
	local c = coroutine.running()
	if not c then
		error("attempt to yield from outside a coroutine")
	end
	timers[c] = get_time() + duration
	return coroutine.yield()
end

---@param func function
function delay.wait(func)
	local c = coroutine.running()
	if not c then
		error("attempt to yield from outside a coroutine")
	end
	waiters[c] = func
	coroutine.yield()
end

---@param object table
---@param key any
---@param duration number
---@param func function
---@param ... any?
---@return function?
function delay.debounce(object, key, duration, func, ...)
	local time = get_time()
	local c = object[key]
	if c then
		if not timers[c] then
			return
		end
		timers[c] = time + duration
		return
	end

	local n = select("#", ...)
	local args = {...}

	-- after sleep timers[c] is set to nil
	-- debounce for this object will do nothing until end of coroutine
	c = coroutine.create(function()
		delay.sleep(duration)
		func(unpack(args, 1, n))
		object[key] = nil
	end)
	object[key] = c
	assert(coroutine.resume(c))
	return function()
		timers[c] = nil
		object[key] = nil
	end
end

---@param interval number
---@param func function
---@param ... any?
---@return function
function delay.every(interval, func, ...)
	local stop = false
	coroutine.wrap(function(...)
		local ptime = get_time()
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
