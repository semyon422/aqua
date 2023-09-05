local delay = require("delay")

local test = {}

function test.sleep()
	local time_obj = {0}
	delay.set_timer(time_obj)

	local sleeped = false
	coroutine.wrap(function()
		delay.sleep(1)
		sleeped = true
	end)()

	assert(not sleeped)

	delay.update()
	assert(not sleeped)

	time_obj[1] = 1
	delay.update()
	assert(sleeped)
end

function test.wait()
	local time_obj = {0}
	delay.set_timer(time_obj)

	local complete = false
	local function check()
		return complete
	end

	local waited = false
	coroutine.wrap(function()
		delay.wait(check)
		waited = true
	end)()

	assert(not waited)

	delay.update()
	assert(not waited)

	complete = true
	delay.update()
	assert(waited)
end

function test.debounce()
	local time_obj = {0}
	delay.set_timer(time_obj)

	local result
	local function add(a, b)
		result = a + b
	end

	local deb_obj = {}

	local function run_debounced()
		delay.debounce(deb_obj, "deb", 1, add, 1, 2)
	end

	run_debounced()
	assert(type(deb_obj.deb) == "thread")
	assert(not result)

	delay.update()
	assert(not result)

	time_obj[1] = 0.5
	delay.update()
	assert(not result)

	run_debounced()

	time_obj[1] = 1.4
	delay.update()
	assert(not result)

	time_obj[1] = 1.5
	delay.update()
	assert(result)
end

function test.debounce_locked()
	local time_obj = {0}
	delay.set_timer(time_obj)

	local c

	local result
	local function add(a, b)
		c = coroutine.running()
		coroutine.yield()
		result = a + b
	end

	local deb_obj = {}

	local function run_debounced()
		delay.debounce(deb_obj, "deb", 1, add, 1, 2)
	end

	run_debounced()
	assert(type(deb_obj.deb) == "thread")
	assert(not result)
	assert(not c)

	time_obj[1] = 1
	delay.update()
	assert(not result)
	assert(c)

	run_debounced()  -- func executing, debounce is locked

	coroutine.resume(c)

	assert(result)
end

function test.every()
	local time_obj = {0}
	delay.set_timer(time_obj)

	local sum = 0
	local function add(a)
		sum = sum + a
	end

	local stop = delay.every(1, add, 2)

	delay.update()
	assert(sum == 0)

	time_obj[1] = 1
	delay.update()
	assert(sum == 2)

	time_obj[1] = 2
	delay.update()
	assert(sum == 4)

	stop()

	time_obj[1] = 3
	delay.update()
	assert(sum == 4)
end

return test
