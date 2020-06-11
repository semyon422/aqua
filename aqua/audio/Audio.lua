local bass = require("aqua.audio.bass")
local bass_fx = require("aqua.audio.bass_fx")
local Class = require("aqua.util.Class")

local Audio = Class:new()

Audio.rateValue = 1
Audio.offset = 0
Audio.baseVolume = 1

Audio.free = function(self) end

Audio.getAdjustTime = function(self)
	if self.audio.playing then
		-- return self.audio:getAudioPosition()
	end
end

Audio.play = function(self)
	self.timer:play()
	bass.BASS_ChannelPlay(self.channel, false)
end

Audio.pause = function(self)
	self.timer:pause()
	bass.BASS_ChannelPause(self.channel)
end

Audio.stop = function(self)
	self.timer:pause()
	self.timer:setPosition(0)
	bass.BASS_ChannelStop(self.channel)
end

Audio.isPlaying = function(self)
	return bass.BASS_ChannelIsActive(self.channel) == 1
end

Audio.update = function(self)
	self.position = self:getPosition()
	self.playing = self:isPlaying()
	self.length = self:getLength()
	self.timer:update()

	local rawPosition = self.position - self.offset
	-- print(self:getAudioPosition(), rawPosition, (rawPosition >= 0 and rawPosition < self:getLength()), self.playing)
	-- print(self.timer:getTime())
	if rawPosition >= 0 and rawPosition < self:getLength() and not self.playing then
		bass.BASS_ChannelSetPosition(self.channel, bass.BASS_ChannelSeconds2Bytes(self.channel, rawPosition), 0)
		bass.BASS_ChannelPlay(self.channel, false)
		-- print("play", rawPosition)
	end
end

Audio.setRate = function(self, rate)
	self.timer:setRate(rate)
	self:setFreqRate(rate)
end

Audio.setFreqRate = function(self, rate)
	if self.rateValue ~= rate then
		self.rateValue = rate
		return bass.BASS_ChannelSetAttribute(self.channel, 1, self.info.freq * rate)
	end
end

Audio.setPitch = function(self, pitch) end

Audio.getPosition = function(self)
	return self.timer:getTime() + self.offset
	-- return bass.BASS_ChannelBytes2Seconds(self.channel, bass.BASS_ChannelGetPosition(self.channel, 0))
end

Audio.getAudioPosition = function(self)
	return bass.BASS_ChannelBytes2Seconds(self.channel, bass.BASS_ChannelGetPosition(self.channel, 0))
end

Audio.setPosition = function(self, position)
	-- error()
	local rawPosition = position - self.offset
	if rawPosition >= 0 and rawPosition < self:getLength() then
		bass.BASS_ChannelSetPosition(self.channel, bass.BASS_ChannelSeconds2Bytes(self.channel, rawPosition), 0)
		bass.BASS_ChannelPlay(self.channel, false)
	else
		-- print("pause")
		bass.BASS_ChannelPause(self.channel)
	end
	self.timer:setPosition(rawPosition)
end

Audio.getLength = function(self)
	local length = bass.BASS_ChannelBytes2Seconds(self.channel, bass.BASS_ChannelGetLength(self.channel, 0))
	if length > 0 then
		return length
	end
	return self.length or 0
end

Audio.setBaseVolume = function(self, volume)
	self.baseVolume = volume
	return self:setVolume(1)
end

Audio.setVolume = function(self, volume)
	return bass.BASS_ChannelSetAttribute(self.channel, 2, volume * self.baseVolume)
end

return Audio
