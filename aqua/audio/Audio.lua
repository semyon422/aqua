local bass = require("aqua.audio.bass")
local bass_fx = require("aqua.audio.bass_fx")
local Class = require("aqua.util.Class")

local Audio = Class:new()

local AudioManager
Audio.construct = function(self)
	if not AudioManager then
		AudioManager = self.AudioManager
	end
	
	self.channel = bass.BASS_SampleGetChannel(self.soundData.sample, false)
end

Audio.removed = false
Audio.manual = false

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
		AudioManager.audios[self] = nil
	end
end

Audio.free = function(self)
	self.manual = false
end

Audio.rate = function(self, rate)
	return bass.BASS_ChannelSetAttribute(self.channel, 1, self.soundData.info.freq * rate)
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
