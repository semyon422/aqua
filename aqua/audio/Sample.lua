local bass = require("aqua.audio.bass")
local bass_fx = require("aqua.audio.bass_fx")
local Audio = require("aqua.audio.Audio")

local Sample = Audio:new()

Sample.construct = function(self)
	self.channel = bass.BASS_SampleGetChannel(self.soundData.sample, false)
end

return Sample
