local bass = require("aqua.audio.bass")
local bass_fx = require("aqua.audio.bass_fx")
local Stream = require("aqua.audio.Stream")

local StreamMemoryTempo = Stream:new()

StreamMemoryTempo.construct = function(self)
	if not self.byteBuffer then
		self:loadData()
	end

	self.channel = bass.BASS_StreamCreateFile(true, self.byteBuffer.pointer, 0, self.byteBuffer.length, 0x200000)
	self.channel = bass_fx.BASS_FX_TempoCreate(self.channel, 0x10000)
end

return StreamMemoryTempo
