local Class = require("aqua.util.Class")

local Container = Class:new()

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
		if not source:isPlaying() then
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
	for source in pairs(self.sources) do
		source:play()
	end
end

Container.pause = function(self)
	for source in pairs(self.sources) do
		source:pause()
	end
end

Container.setPosition = function(self, position)
	for source in pairs(self.sources) do
		if source:isPlaying() then
			local newPosition = position - source.offset
			if newPosition >= 0 and newPosition < source:getLength() then
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
	local length = 0

	for source in pairs(self.sources) do
		local pos = source:getPosition()
		if source:isPlaying() then
			local _length = source:getLength()
			position = position + (source.offset + pos) * _length
			length = length + _length
		end
	end

	if length == 0 then
		return nil
	end

	return position / length
end

return Container
