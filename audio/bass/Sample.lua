local class = require("class_new")
local BassSource = require("audio.bass.BassSource")
local bass = require("bass")
local bass_assert = require("bass.assert")

local Sample, new = class(BassSource)

function Sample:new(soundData)
	self.soundData = soundData
	self.info = soundData.info
	self.channel = bass.BASS_SampleGetChannel(self.soundData.sample, 1)  -- BASS_SAMCHAN_NEW
	bass_assert(self.channel ~= 0)
end

return new
