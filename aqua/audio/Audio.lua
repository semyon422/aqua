local bass = require("aqua.audio.bass")
local bass_fx = require("aqua.audio.bass_fx")
local Class = require("aqua.util.Class")

local Audio = Class:new()

Audio.construct = function(self)
	self.channel = bass.BASS_SampleGetChannel(self.soundData.sample, false)
end

Audio.removed = false
Audio.manual = false
Audio.rateValue = 1

Audio.play = function(self)
	return bass.BASS_ChannelPlay(self.channel, false)
end

Audio.pause = function(self)
	return bass.BASS_ChannelPause(self.channel)
end

Audio.stop = function(self)
	return bass.BASS_ChannelStop(self.channel)
end

Audio.update = function(self)
	if not self.manual and bass.BASS_ChannelIsActive(self.channel) == 0 then
		self.AudioManager.audios:remove(self)
	end
end

Audio.free = function(self)
	self.manual = false
end

Audio.rate = function(self, rate)
	if self.rateValue ~= rate then
		self.rateValue = rate
		return bass.BASS_ChannelSetAttribute(self.channel, 1, self.soundData.info.freq * rate)
	end
end

Audio.position = function(self)
	return tonumber(bass.BASS_ChannelGetPosition(self.channel, 0)) / 1e5
end

Audio.seek = function(self, position)
	return bass.BASS_ChannelSetPosition(self.channel, bass.BASS_ChannelSeconds2Bytes(self.channel, position));
end

Audio.length = function(self)
	return bass.BASS_ChannelBytes2Seconds(self.channel, bass.BASS_ChannelGetLength(self.channel))
end

return Audio
