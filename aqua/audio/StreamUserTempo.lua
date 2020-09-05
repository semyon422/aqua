local ffi = require("ffi")
local bass = require("aqua.audio.bass")
local bass_fx = require("aqua.audio.bass_fx")
local Stream = require("aqua.audio.Stream")

local StreamUserTempo = Stream:new()

StreamUserTempo.construct = function(self)
	self.file = love.filesystem.newFile(self.path, "r")
	self.idPointer = ffi.new("int32_t[1]")
	self.idPointer[0] = bass.addFile(self.file)
	self.channel = bass.BASS_StreamCreateFileUser(1, 0x220000, bass.fileProcs, self.idPointer)
	self.channel = bass_fx.BASS_FX_TempoCreate(self.channel, 0x10000)
end

StreamUserTempo.setRate = function(self, rate)
	if self.rateValue ~= rate then
		self.rateValue = rate
		return bass.BASS_ChannelSetAttribute(self.channel, 0x10000, (rate - 1) * 100)
	end
end

StreamUserTempo.setPitch = function(self, pitch)
	-- semitone 1 : 2^(1/12)
	if self.pitchValue ~= pitch then
		self.pitchValue = pitch
		return bass.BASS_ChannelSetAttribute(self.channel, 0x10001, 12 * math.log(pitch) / math.log(2))
	end
end

StreamUserTempo.free = function(self)
	bass.removeFile(self.idPointer[0])
	Stream.free(self)
end

return StreamUserTempo
