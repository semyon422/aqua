local ffi = require("ffi")
local byte = require("byte")
local sound = require("aqua.sound")
local bass = require("aqua.audio.bass")
local bass_fx = require("aqua.audio.bass_fx")
local Audio = require("aqua.audio.Audio")

local Stream = Audio:new()

Stream.construct = function(self) end

Stream.loadData = function(self)
	local soundData = self.soundData

	local content = soundData.fileData:getString()
	self.byteBuffer = byte.buffer(content, 0, nil, true)
	self.info = soundData.info
end

Stream.setRate = function(self, rate)
	if self.rateValue ~= rate then
		self.rateValue = rate
		return bass.BASS_ChannelSetAttribute(self.channel, 0x10000, (rate - 1) * 100)
	end
end

Stream.setPitch = function(self, pitch)
	-- semitone 1 : 2^(1/12)
	if self.pitchValue ~= pitch then
		self.pitchValue = pitch
		return bass.BASS_ChannelSetAttribute(self.channel, 0x10001, 12 * math.log(pitch) / math.log(2))
	end
end

Stream.free = function(self)
	bass.BASS_StreamFree(self.channel)
end

return Stream
