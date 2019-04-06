local Class = require("aqua.util.Class")

local Timer = Class:new()

Timer.rate = 1
Timer.currentTime = 0
Timer.pauseTime = 0
Timer.adjustDelta = 0
Timer.rateDelta = 0
Timer.state = "waiting"

Timer.update = function(self, dt)
	local deltaTime = love.timer.getTime() - (self.startTime or 0)
	self.deltaTime = deltaTime
	
	if self.state == "waiting" then
		return
	elseif self.state == "playing" then
		self.currentTime = (deltaTime - self.adjustDelta - self.pauseTime - self.rateDelta) * self.rate
	end
	
	if self.getAdjustTime then
		self:adjustTime(dt)
	end
end

Timer.adjustTime = function(self, dt, force)
	local adjustTime = self:getAdjustTime()
	if adjustTime and self.state ~= "paused" then
		dt = math.min(dt, 1 / 60)
		local targetAdjustDelta
			= self.deltaTime
			- self.rateDelta
			- self.pauseTime
			- adjustTime
			/ self.rate
		
		if force then
			self.adjustDelta = targetAdjustDelta
		else
			self.adjustDelta
				= self.adjustDelta
				+ (targetAdjustDelta - self.adjustDelta)
				* dt
		end
	end
end

Timer.setRate = function(self, rate)
	if self.startTime then
		local pauseTime
		if self.state == "paused" then
			pauseTime = self.pauseTime + love.timer.getTime() - self.pauseStartTime
		else
			pauseTime = self.pauseTime
		end
		local deltaTime = love.timer.getTime() - self.startTime - pauseTime
		self.rateDelta = (self.rateDelta - deltaTime) * self.rate / rate + deltaTime
	end
	self.rate = rate
end

Timer.getTime = function(self)
	return self.currentTime
end

Timer.pause = function(self)
	self.state = "paused"
	self.pauseStartTime = love.timer.getTime()
end

Timer.play = function(self)
	if self.state == "waiting" then
		self.state = "playing"
		self.startTime = love.timer.getTime() - self.currentTime
	elseif self.state == "paused" then
		self.state = "playing"
		self.pauseTime = self.pauseTime + love.timer.getTime() - self.pauseStartTime
		self.pauseStartTime = love.timer.getTime()
	end
end

return Timer
