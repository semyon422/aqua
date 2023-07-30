local Class = require("Class")

local Container = Class:new()

Container.playing = false
Container.volume = 1
Container.rate = 1
Container.pitch = 1

Container.construct = function(self)
	self.sources = {}
end

Container.add = function(self, source)
	self.sources[source] = true
	source:setVolume(self.volume)
	source:setRate(self.rate)
	source:setPitch(self.pitch)
	source:play()
end

Container.update = function(self)
	for source in pairs(self.sources) do
		if self.playing and not source:isPlaying() then
			source:release()
			self.sources[source] = nil
		end
	end
end

Container.release = function(self)
	for source in pairs(self.sources) do
		source:release()
	end
	self.sources = {}
	self.playing = false
end

Container.setRate = function(self, rate)
	self.rate = rate
	for source in pairs(self.sources) do
		source:setRate(rate)
	end
end

Container.setPitch = function(self, pitch)
	self.pitch = pitch
	for source in pairs(self.sources) do
		source:setPitch(pitch)
	end
end

Container.setVolume = function(self, volume)
	self.volume = volume
	for source in pairs(self.sources) do
		source:setVolume(volume)
	end
end

Container.play = function(self)
	self.playing = true
	for source in pairs(self.sources) do
		source:play()
	end
end

Container.pause = function(self)
	self.playing = false
	for source in pairs(self.sources) do
		source:pause()
	end
end

Container.setPosition = function(self, position)
	for source in pairs(self.sources) do
		if source:isPlaying() then
			local newPosition = position - source.offset
			if newPosition >= 0 and newPosition < source:getDuration() then
				source:setPosition(newPosition)
			else
				source:release()
				self.sources[source] = nil
			end
		end
	end
end

Container.getPosition = function(self)
	local position = 0
	local minPos, maxPos = math.huge, -math.huge
	local length = 0

	for source in pairs(self.sources) do
		local pos = source:getPosition()
		if source:isPlaying() then
			local _length = source:getDuration()
			local _pos = source.offset + pos
			minPos = math.min(minPos, _pos)
			maxPos = math.max(maxPos, _pos)
			position = position + _pos * _length
			length = length + _length
		end
	end

	if length == 0 then
		return nil
	end

	return position / length, minPos, maxPos
end

return Container
