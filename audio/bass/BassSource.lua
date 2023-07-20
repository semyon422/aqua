local class = require("class_new")
local Source = require("audio.Source")
local bass = require("bass")
local bass_assert = require("bass.assert")

local BassSource, new = class(Source)

function BassSource:release()
	bass_assert(bass.BASS_ChannelFree(self.channel) == 1)
end

function BassSource:play()
	bass_assert(bass.BASS_ChannelPlay(self.channel, false) == 1)
end

function BassSource:pause()
	-- bass_assert(bass.BASS_ChannelPause(self.channel) == 1)
	-- A sample channel can be ended after last BASS_ChannelIsActive.
	-- Don't assert here.
	bass.BASS_ChannelPause(self.channel)
end

function BassSource:stop()
	self:pause()
	self:setPosition(0)
end

function BassSource:isPlaying()
	return bass.BASS_ChannelIsActive(self.channel) ~= 0
end

function BassSource:setRate(rate)
	return self:setFreqRate(rate)
end

function BassSource:setFreqRate(rate)
	if self.rateValue ~= rate then
		self.rateValue = rate
		bass.BASS_ChannelSetAttribute(self.channel, 1, self.info.freq * rate)
		-- bass_assert(bass.BASS_ChannelSetAttribute(self.channel, 1, self.info.freq * rate) == 1)
	end
end

function BassSource:getPosition()
	local pos = bass.BASS_ChannelGetPosition(self.channel, 0)
	bass_assert(pos >= 0)
	pos = bass.BASS_ChannelBytes2Seconds(self.channel, pos)
	bass_assert(pos >= 0)
	return pos
end

function BassSource:setPosition(position)
	local length = bass.BASS_ChannelGetLength(self.channel, 0)
	bass_assert(length >= 0)
	local pos = bass.BASS_ChannelSeconds2Bytes(self.channel, position)
	bass_assert(pos >= 0)
	if pos >= length then
		pos = length - 1
	end
	pos = bass.BASS_ChannelSetPosition(self.channel, pos, 0)
	bass_assert(pos == 1)
end

function BassSource:getLength()
	local length = bass.BASS_ChannelGetLength(self.channel, 0)
	bass_assert(length >= 0)
	length = bass.BASS_ChannelBytes2Seconds(self.channel, length)
	bass_assert(length >= 0)
	return length
end

function BassSource:setBaseVolume(volume)
	self.baseVolume = volume
	return self:setVolume(1)
end

function BassSource:setVolume(volume)
	bass_assert(bass.BASS_ChannelSetAttribute(self.channel, 2, volume * self.baseVolume) == 1)
end

return new
