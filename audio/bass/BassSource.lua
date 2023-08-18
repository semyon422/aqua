local Source = require("audio.Source")
local bass = require("bass")
local bass_assert = require("bass.assert")

---@class audio.bass.BassSource: audio.Source
---@operator call:audio.bass.BassSource
local BassSource = Source + {}

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

---@return boolean
function BassSource:isPlaying()
	return bass.BASS_ChannelIsActive(self.channel) == 1  -- BASS_ACTIVE_PLAYING
end

---@param rate number
function BassSource:setRate(rate)
	self:setFreqRate(rate)
end

---@param rate number
function BassSource:setFreqRate(rate)
	if self.rateValue == rate then
		return
	end
	self.rateValue = rate
	bass.BASS_ChannelSetAttribute(self.channel, 1, self.info.freq * rate)
	-- bass_assert(bass.BASS_ChannelSetAttribute(self.channel, 1, self.info.freq * rate) == 1)
end

---@return number
function BassSource:getPosition()
	local pos = bass.BASS_ChannelGetPosition(self.channel, 0)
	bass_assert(pos >= 0)
	pos = bass.BASS_ChannelBytes2Seconds(self.channel, pos)
	bass_assert(pos >= 0)
	return pos
end

---@param position number
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

---@return number
function BassSource:getDuration()
	local length = bass.BASS_ChannelGetLength(self.channel, 0)
	bass_assert(length >= 0)
	length = bass.BASS_ChannelBytes2Seconds(self.channel, length)
	bass_assert(length >= 0)
	return length
end

---@param volume number
function BassSource:setBaseVolume(volume)
	self.baseVolume = volume
	self:setVolume(1)
end

---@param volume number
function BassSource:setVolume(volume)
	bass_assert(bass.BASS_ChannelSetAttribute(self.channel, 2, volume * self.baseVolume) == 1)
end

return BassSource
