local bass = require("aqua.audio.bass")
local bass_fx = require("aqua.audio.bass_fx")
local Class = require("aqua.util.Class")

local Audio = Class:new()

Audio.rateValue = 1
Audio.offset = 0
Audio.baseVolume = 1

Audio.free = function(self) end

Audio.play = function(self)
	return bass.BASS_ChannelPlay(self.channel, false)
end

Audio.pause = function(self)
	return bass.BASS_ChannelPause(self.channel)
end

Audio.stop = function(self)
	return bass.BASS_ChannelStop(self.channel)
end

Audio.isPlaying = function(self)
	return bass.BASS_ChannelIsActive(self.channel) ~= 0
end

Audio.update = function(self)
end

Audio.setRate = function(self, rate)
	return self:setFreqRate(rate)
end

Audio.setFreqRate = function(self, rate)
	if self.rateValue ~= rate then
		self.rateValue = rate
		return bass.BASS_ChannelSetAttribute(self.channel, 1, self.info.freq * rate)
	end
end

Audio.setPitch = function(self, pitch) end

Audio.getPosition = function(self)
	return bass.BASS_ChannelBytes2Seconds(self.channel, bass.BASS_ChannelGetPosition(self.channel, 0))
end

Audio.setPosition = function(self, position)
	return bass.BASS_ChannelSetPosition(self.channel, bass.BASS_ChannelSeconds2Bytes(self.channel, position), 0)
end

Audio.getLength = function(self)
	return bass.BASS_ChannelBytes2Seconds(self.channel, bass.BASS_ChannelGetLength(self.channel, 0))
end

Audio.setBaseVolume = function(self, volume)
	self.baseVolume = volume
	return self:setVolume(1)
end

Audio.setVolume = function(self, volume)
	return bass.BASS_ChannelSetAttribute(self.channel, 2, volume * self.baseVolume)
end

return Audio
