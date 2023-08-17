local class = require("class")

---@class util.Timer
---@operator call: util.Timer
local Timer = class()

Timer.isPlaying = false
Timer.offset = 0
Timer.rate = 1
Timer.adjustRate = 0.1

---@return number
function Timer:getAbsoluteTime()
	return 0
end

---@return number?
function Timer:tryAdjust()
	if not self.getAdjustTime then
		return
	end
	local adjustTime = self:getAdjustTime()
	if not adjustTime then
		return
	end
	if adjustTime == self.prevAdjustTime then
		return
	end
	self.prevAdjustTime = adjustTime
	return adjustTime
end

---@return number
function Timer:getTime()
	if not self.isPlaying then
		return self.offset
	end

	local dt = self:getAbsoluteTime() - self.startTime
	local time = dt * self.rate + self.offset

	local adjustTime = self:tryAdjust()
	if adjustTime and self.adjustRate > 0 then
		time = time + (adjustTime - time) * self.adjustRate
		self:setTime(time)
	end

	return time
end

---@param time number
---@return number
function Timer:transform(time)
	return time - self:getAbsoluteTime() + self:getTime()
end

---@param time number?
function Timer:setTime(time)
	self.offset = time or self:getTime()
	self.startTime = self:getAbsoluteTime()
end

---@param rate number
function Timer:setRate(rate)
	self:setTime()
	self.rate = rate
end

function Timer:pause()
	if not self.isPlaying then
		return
	end

	self:setTime()
	self.isPlaying = false
end

function Timer:play()
	if self.isPlaying then
		return
	end

	self:setTime()
	self.isPlaying = true
end

return Timer
