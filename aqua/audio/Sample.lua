local bass = require("aqua.audio.bass")
local Audio = require("aqua.audio.Audio")
local Timer = require("aqua.util.Timer")

local Sample = Audio:new()

Sample.construct = function(self)
	self.info = self.soundData.info
	self.channel = bass.BASS_SampleGetChannel(self.soundData.sample, false)
	self.timer = Timer:new()
	self.timer.audio = self
	self.timer.getAdjustTime = self.getAdjustTime
end

return Sample
