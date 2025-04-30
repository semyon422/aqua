local BassSource = require("audio.bass.BassSource")
local bass = require("bass")
local bass_fx = require("bass.fx")
local bass_assert = require("bass.assert")

---@class audio.bass.StreamMemoryTempo: audio.bass.BassSource
---@operator call:audio.bass.StreamMemoryTempo
local StreamMemoryTempo = BassSource + {}

---@param soundData audio.bass.BassSoundData
function StreamMemoryTempo:new(soundData)
	self.soundData = soundData
	self.channel = bass.BASS_SampleGetChannel(soundData.sample, 0x200002) -- BASS_STREAM_DECODE | BASS_SAMCHAN_STREAM
	bass_assert(self.channel ~= 0)
	self.channel = bass_fx.BASS_FX_TempoCreate(self.channel, 0x10000)
	bass_assert(self.channel ~= 0)
	self:readChannelInfo()
end

---@param rate number
function StreamMemoryTempo:setRate(rate)
	if self.rateValue == rate then
		return
	end
	self.rateValue = rate
	bass_assert(bass.BASS_ChannelSetAttribute(self.channel, 0x10000, (rate - 1) * 100) == 1)
end

---@param pitch number
function StreamMemoryTempo:setPitch(pitch)
	if self.pitchValue == pitch then
		return
	end
	-- semitone 1 : 2^(1/12)
	self.pitchValue = pitch
	bass_assert(bass.BASS_ChannelSetAttribute(self.channel, 0x10001, 12 * math.log(pitch, 2)) == 1)
end

return StreamMemoryTempo
