local bass = require("audio.bass")
local bass_assert = require("audio.bass_assert")
local Source = require("audio.Source")

local BassSource = Source:new()

BassSource.release = function(self)
	-- bass_assert(bass.BASS_ChannelFree(self.channel) == 1)
	-- A sample channel (HCHANNEL) is automatically freed when it is overridden by a new channel.
	-- Don't assert here.
	bass.BASS_ChannelFree(self.channel)
end

BassSource.play = function(self)
	bass_assert(bass.BASS_ChannelPlay(self.channel, false) == 1)
end

BassSource.pause = function(self)
	-- bass_assert(bass.BASS_ChannelPause(self.channel) == 1)
	-- A sample channel can be ended after last BASS_ChannelIsActive.
	-- Don't assert here.
	bass.BASS_ChannelPause(self.channel)
end

BassSource.stop = function(self)
	self:pause()
	self:setPosition(0)
end

BassSource.isPlaying = function(self)
	return bass.BASS_ChannelIsActive(self.channel) ~= 0
end

BassSource.setRate = function(self, rate)
	return self:setFreqRate(rate)
end

BassSource.setFreqRate = function(self, rate)
	if self.rateValue ~= rate then
		self.rateValue = rate
		bass_assert(bass.BASS_ChannelSetAttribute(self.channel, 1, self.info.freq * rate) == 1)
	end
end

BassSource.getPosition = function(self)
	local pos = bass.BASS_ChannelGetPosition(self.channel, 0)
	bass_assert(pos >= 0)
	pos = bass.BASS_ChannelBytes2Seconds(self.channel, pos)
	bass_assert(pos >= 0)
	return pos
end

BassSource.setPosition = function(self, position)
	local pos = bass.BASS_ChannelSeconds2Bytes(self.channel, position)
	bass_assert(pos >= 0)
	pos = bass.BASS_ChannelSetPosition(self.channel, pos, 0)
	bass_assert(pos == 1)
end

BassSource.getLength = function(self)
	local length = bass.BASS_ChannelGetLength(self.channel, 0)
	bass_assert(length >= 0)
	length = bass.BASS_ChannelBytes2Seconds(self.channel, length)
	bass_assert(length >= 0)
	return length
end

BassSource.setBaseVolume = function(self, volume)
	self.baseVolume = volume
	return self:setVolume(1)
end

BassSource.setVolume = function(self, volume)
	bass_assert(bass.BASS_ChannelSetAttribute(self.channel, 2, volume * self.baseVolume) == 1)
end

return BassSource
