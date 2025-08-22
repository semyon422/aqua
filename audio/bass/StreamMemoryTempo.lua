local bit = require("bit")
local BassSource = require("audio.bass.BassSource")
local bass = require("bass")
local bass_fx = require("bass.fx")
local bass_assert = require("bass.assert")
local bass_flags = require("bass.flags")

---@class audio.bass.StreamMemoryTempo: audio.bass.BassSource
---@operator call:audio.bass.StreamMemoryTempo
local StreamMemoryTempo = BassSource + {}

---@param soundData audio.bass.BassSoundData
function StreamMemoryTempo:new(soundData)
	self.soundData = soundData
	self.channel = bass.BASS_SampleGetChannel(soundData.sample, bit.bor(bass_flags.BASS_STREAM_DECODE, bass_flags.BASS_SAMCHAN_STREAM))
	bass_assert(self.channel ~= 0)
	self.channel = bass_fx.BASS_FX_TempoCreate(self.channel, bass_flags.BASS_FX_FREESOURCE)
	bass_assert(self.channel ~= 0)
	self:readChannelInfo()
end

---@param rate number
function StreamMemoryTempo:setRate(rate)
	if self.rateValue == rate then
		return
	end
	self.rateValue = rate
	bass_assert(bass.BASS_ChannelSetAttribute(self.channel, bass_flags.BASS_ATTRIB_TEMPO, (rate - 1) * 100) == 1)
end

---@param pitch number
function StreamMemoryTempo:setPitch(pitch)
	if self.pitchValue == pitch then
		return
	end
	-- semitone 1 : 2^(1/12)
	self.pitchValue = pitch
	bass_assert(bass.BASS_ChannelSetAttribute(self.channel, bass_flags.BASS_ATTRIB_TEMPO_PITCH, 12 * math.log(pitch, 2)) == 1)
end

return StreamMemoryTempo
