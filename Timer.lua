local Class = require("Class")

local Timer = Class:new()

local love = love

Timer.construct = function(self)
	self:reset()
end

Timer.reset = function(self)
	self.startTime = self:getAbsoluteTime()
	self.pauseStartTime = self.startTime
	self.isPlaying = false
	self.currentTime = 0
	self.deltaTime = 0
	self.rate = 1
	self.currentTime = 0
	self.pauseTime = 0
	self.adjustDelta = 0
	self.rateDelta = 0
	self.positionDelta = 0
end

Timer.getAbsoluteTime = function(self)
	if love then
		return love.timer.getTime()
	end
	return os.time()
end

Timer.getAbsoluteDelta = function(self)
	if love then
		return love.timer.getDelta()
	end
	return 0
end

Timer.update = function(self)
	self.deltaTime = self:getAbsoluteTime() - self.startTime

	if not self.isPlaying then
		return
	end
	self.currentTime = (self.deltaTime - self.adjustDelta - self.pauseTime - self.rateDelta) * self.rate + self.positionDelta

	if self.getAdjustTime then
		self:adjustTime()
	end
end

Timer.adjustTime = function(self, force)
	local adjustTime = self:getAdjustTime()
	if not adjustTime or not self.isPlaying then
		return
	end

	local dt = math.min(self:getAbsoluteDelta(), 1 / 60)
	local targetAdjustDelta
		= self.deltaTime
		- self.rateDelta
		- self.pauseTime
		- (adjustTime - self.positionDelta)
		/ self.rate

	if force then
		self.adjustDelta = targetAdjustDelta
		return
	end

	self.adjustDelta = self.adjustDelta + (targetAdjustDelta - self.adjustDelta) * dt
end

Timer.setRate = function(self, rate)
	local pauseTime = self.pauseTime
	local time = self:getAbsoluteTime()
	if not self.isPlaying then
		pauseTime = pauseTime + time - self.pauseStartTime
	end
	local deltaTime = time - self.startTime - pauseTime
	self.rateDelta = (self.rateDelta - deltaTime) * self.rate / rate + deltaTime

	local adjust = false
	if rate * self.rate < 0 then
		if self.getAdjustTime then
			adjust = true
		end
	end

	self.rate = rate

	if adjust then
		self:adjustTime(true)
	end
end

Timer.getTime = function(self)
	return self.currentTime
end

Timer.transformTime = function(self, eventTime)
	return eventTime - self:getAbsoluteTime() + self:getTime()
end

Timer.setPosition = function(self, position)
	local currentTime = self.currentTime - self.positionDelta
	self.positionDelta = position - currentTime
	self.currentTime = currentTime + self.positionDelta
end

Timer.pause = function(self)
	if not self.isPlaying then
		return
	end

	self.isPlaying = false
	self.pauseStartTime = self:getAbsoluteTime()
end

Timer.play = function(self)
	if self.isPlaying then
		return
	end

	local time = self:getAbsoluteTime()
	self.isPlaying = true
	self.pauseTime = self.pauseTime + time - self.pauseStartTime
	self.pauseStartTime = time
end

return Timer
