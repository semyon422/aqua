local StreamMemoryTempo = require("aqua.audio.StreamMemoryTempo")
local StreamMemoryReverse = require("aqua.audio.StreamMemoryReverse")
local Stream = require("aqua.audio.Stream")

local StreamMemoryReversable = Stream:new()

StreamMemoryReversable.construct = function(self)
	self.streamDirect = StreamMemoryTempo:new({soundData = self.soundData, info = self.info})
	self.streamReversed = StreamMemoryReverse:new({soundData = self.soundData, info = self.info})
end

StreamMemoryReversable.rateValue = 1
StreamMemoryReversable.offset = 0
StreamMemoryReversable.baseVolume = 1

StreamMemoryReversable.release = function(self)
	self.streamDirect:release()
	self.streamReversed:release()
end

StreamMemoryReversable.play = function(self)
	if self.rateValue > 0 then
		return self.streamDirect:play()
	elseif self.rateValue < 0 then
		return self.streamReversed:play()
	end
end

StreamMemoryReversable.pause = function(self)
	if self.rateValue > 0 then
		return self.streamDirect:pause()
	elseif self.rateValue < 0 then
		return self.streamReversed:pause()
	end
end

StreamMemoryReversable.stop = function(self)
	if self.rateValue > 0 then
		return self.streamDirect:stop()
	elseif self.rateValue < 0 then
		return self.streamReversed:stop()
	end
end

StreamMemoryReversable.isPlaying = function(self)
	if self.rateValue > 0 then
		return self.streamDirect:isPlaying()
	elseif self.rateValue < 0 then
		return self.streamReversed:isPlaying()
	end
end

StreamMemoryReversable.setRate = function(self, rate)
	if self.rateValue > 0 and rate > 0 then
		self.streamDirect:setRate(rate)
	elseif self.rateValue < 0 and rate < 0 then
		self.streamReversed:setRate(-rate)
	elseif self.rateValue > 0 and rate < 0 then
		self.streamDirect:pause()
		self.streamReversed:setFreqRate(-rate)
		self.streamReversed:setPosition(self.streamDirect:getPosition())
		self.streamReversed:play()
	elseif self.rateValue < 0 and rate > 0 then
		self.streamReversed:pause()
		self.streamDirect:setRate(rate)
		self.streamDirect:setPosition(self.streamReversed:getPosition())
		self.streamDirect:play()
	end
	if rate ~= 0 then
		self.rateValue = rate
	end
end

StreamMemoryReversable.setPitch = function(self, pitch) end

StreamMemoryReversable.getPosition = function(self)
	if self.rateValue > 0 then
		return self.streamDirect:getPosition()
	elseif self.rateValue < 0 then
		return self.streamReversed:getPosition()
	end
end

StreamMemoryReversable.setPosition = function(self, position)
	if self.rateValue > 0 then
		return self.streamDirect:setPosition(position)
	elseif self.rateValue < 0 then
		return self.streamReversed:setPosition(position)
	end
end

StreamMemoryReversable.getLength = function(self)
	return self.streamDirect:getLength()
end

StreamMemoryReversable.setBaseVolume = function(self, volume)
	self.streamDirect:setBaseVolume(volume)
	self.streamReversed:setBaseVolume(volume)
end

StreamMemoryReversable.setVolume = function(self, volume)
	self.streamDirect:setVolume(volume)
	self.streamReversed:setVolume(volume)
end

return StreamMemoryReversable
