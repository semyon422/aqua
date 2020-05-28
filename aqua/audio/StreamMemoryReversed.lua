local ffi = require("ffi")
local byte = require("byte")
local loveffi = require("aqua.loveffi")
local bass = require("aqua.audio.bass")
local bass_fx = require("aqua.audio.bass_fx")
local Stream = require("aqua.audio.Stream")

local StreamMemoryReversed = Stream:new()

StreamMemoryReversed.construct = function(self)
	if not self.byteBuffer then
		self:loadData(self.path)
	end

	self.channel = bass.BASS_StreamCreateFile(true, self.byteBuffer.pointer, 0, self.byteBuffer.length, 0x200000)
	self.channel = bass_fx.BASS_FX_ReverseCreate(self.channel, self:getLength(), 0x10000)
end

return StreamMemoryReversed
