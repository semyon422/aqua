local bass = require("aqua.audio.bass")
local Audio = require("aqua.audio.Audio")

local Sample = Audio:new()

Sample.construct = function(self)
	self.info = self.soundData.info
	self.channel = bass.BASS_SampleGetChannel(self.soundData.sample, false)
end

Sample.free = function(self)
	bass.BASS_ChannelFree(self.channel)
end

return Sample
