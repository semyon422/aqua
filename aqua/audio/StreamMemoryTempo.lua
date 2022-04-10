local bass = require("aqua.audio.bass")
local bass_fx = require("aqua.audio.bass_fx")
local Stream = require("aqua.audio.Stream")
local StreamTempo = require("aqua.audio.StreamTempo")

local StreamMemoryTempo = Stream:new()

StreamMemoryTempo.construct = function(self)
	local fileData = self.soundData.fileData
	self.channelDecode = bass.BASS_StreamCreateFile(true, fileData:getFFIPointer(), 0, fileData:getSize(), 0x220000)
	self.channel = bass_fx.BASS_FX_TempoCreate(self.channelDecode, 0x10000)
end

StreamMemoryTempo.free = function(self)
	bass.BASS_ChannelFree(self.channel)
	bass.BASS_ChannelFree(self.channelDecode)
end

StreamMemoryTempo.setRate = StreamTempo.setRate

StreamMemoryTempo.setPitch = StreamTempo.setPitch

return StreamMemoryTempo
