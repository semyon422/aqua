local bass = require("aqua.audio.bass")
local Class = require("aqua.util.Class")

local Audio = Class:new()

local AudioManager
Audio.construct = function(self)
	if not AudioManager then
		AudioManager = self.AudioManager
	end
end

Audio.removed = false
Audio.manual = false

Audio.play = function(self)
	self.channel = self.channel or bass.BASS_SampleGetChannel(self.chunk, false)
	bass.BASS_ChannelPlay(self.channel, false)
end

Audio.pause = function(self)
	bass.BASS_ChannelPause(self.channel)
end

Audio.stop = function(self)
	bass.BASS_ChannelStop(self.channel)
end

Audio.getPosition = function(self)
	return tonumber(bass.BASS_ChannelGetPosition(self.channel, 0)) / 1e5
end

Audio.update = function(self)
	if not self.manual and bass.BASS_ChannelIsActive(self.channel) == 0 then
		AudioManager.audios[self] = false
	end
end

Audio.free = function(self)
	self.manual = false
end

return Audio
