local bass = require("aqua.audio.bass")
local bass_assert = require("aqua.audio.bass_assert")
local BassSource = require("aqua.audio.BassSource")

local Sample = BassSource:new()

Sample.construct = function(self)
	self.info = self.soundData.info
	self.channel = bass.BASS_SampleGetChannel(self.soundData.sample, 0)
	bass_assert(self.channel ~= 0)
end

return Sample
