local Source = require("aqua.audio.Source")

local AudioOpenAL = Source:new()

AudioOpenAL.construct = function(self)
	if not self.path then
		return
	end
	self.source = love.audio.newSource(self.path, "stream")
end

AudioOpenAL.release = function(self)
	if self.source then
		self.source:release()
		self.source = nil
	end
end

AudioOpenAL.play = function(self)
	return self.source and self.source:play()
end

AudioOpenAL.pause = function(self)
	return self.source and self.source:pause()
end

AudioOpenAL.stop = function(self)
	return self.source and self.source:stop()
end

AudioOpenAL.isPlaying = function(self)
	return self.source and self.source:isPlaying()
end

AudioOpenAL.setRate = function(self, rate)
	return self:setFreqRate(rate)
end

AudioOpenAL.setFreqRate = function(self, rate)
	if self.rateValue ~= rate then
		self.rateValue = rate
		return self.source and self.source:setPitch(rate)
	end
end

AudioOpenAL.getPosition = function(self)
	return self.source and self.source:tell()
end

AudioOpenAL.setPosition = function(self, position)
	if not self.source or position < 0 or position > self:getLength() then
		return
	end
	return self.source:seek(position)
end

AudioOpenAL.getLength = function(self)
	return self.source and self.source:getDuration()
end

AudioOpenAL.setBaseVolume = function(self, volume)
	self.baseVolume = volume
	return self:setVolume(1)
end

AudioOpenAL.setVolume = function(self, volume)
	return self.source and self.source:setVolume(volume * self.baseVolume)
end

return AudioOpenAL
