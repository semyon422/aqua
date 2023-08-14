local Timer = require("Timer")

local time
function Timer:getAbsoluteTime()
	return time
end

do
	time = 0
	local timer = Timer()

	timer:play()

	assert(timer:getTime() == 0)

	time = 1

	assert(timer:getTime() == 1)

	timer:setRate(2)
	time = 2

	assert(timer:getTime() == 3)

	timer:setTime(2)

	assert(timer:getTime() == 2)

	timer:setRate(0.5)
	time = 3

	assert(timer:getTime() == 2.5)

	timer:pause()
	time = 4

	assert(timer:getTime() == 2.5)

	timer:play()

	assert(timer:getTime() == 2.5)

	time = 5

	assert(timer:getTime() == 3)
end

do
	time = 0
	local adjTime = 0

	local timer = Timer()
	timer.adjustRate = 1
	function timer:getAdjustTime()
		return adjTime
	end

	timer:play()

	assert(timer:getTime() == 0)

	time = 1
	adjTime = 1

	assert(timer:getTime() == 1)

	time = 2
	adjTime = 2

	assert(timer:getTime() == 2)

	time = 2
	adjTime = 3

	assert(timer:getTime() == 3)

	time = 3
	adjTime = 3

	assert(timer:getTime() == 4)
end
