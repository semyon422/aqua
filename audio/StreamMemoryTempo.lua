local bass = require("audio.bass")
local bass_fx = require("audio.bass_fx")
local bass_assert = require("audio.bass_assert")
local BassSource = require("audio.BassSource")

local StreamMemoryTempo = BassSource:new()

StreamMemoryTempo.construct = function(self)
	self.info = self.soundData.info
	self.channel = bass.BASS_SampleGetChannel(self.soundData.sample, 0x200002)  -- BASS_STREAM_DECODE | BASS_SAMCHAN_STREAM
	bass_assert(self.channel ~= 0)
	self.channel = bass_fx.BASS_FX_TempoCreate(self.channel, 0x10000)
	bass_assert(self.channel ~= 0)
end

StreamMemoryTempo.setRate = function(self, rate)
	if self.rateValue ~= rate then
		self.rateValue = rate
		bass_assert(bass.BASS_ChannelSetAttribute(self.channel, 0x10000, (rate - 1) * 100) == 1)
	end
end

StreamMemoryTempo.setPitch = function(self, pitch)
	-- semitone 1 : 2^(1/12)
	if self.pitchValue ~= pitch then
		self.pitchValue = pitch
		bass_assert(bass.BASS_ChannelSetAttribute(self.channel, 0x10001, 12 * math.log(pitch) / math.log(2)) == 1)
	end
end

return StreamMemoryTempo
