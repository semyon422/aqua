local BassSource = require("audio.bass.BassSource")
local bass = require("bass")
local bass_assert = require("bass.assert")
local bass_flags = require("bass.flags")

---@class audio.bass.Sample: audio.bass.BassSource
---@operator call:audio.bass.Sample
local Sample = BassSource + {}

---@param soundData audio.bass.BassSoundData
function Sample:new(soundData)
	self.soundData = soundData
	self.channel = bass.BASS_SampleGetChannel(self.soundData.sample, bass_flags.BASS_SAMCHAN_NEW)
	bass_assert(self.channel ~= 0)
	self:readChannelInfo()
end

return Sample
