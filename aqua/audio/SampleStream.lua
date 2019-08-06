local ffi = require("ffi")
local bass = require("aqua.audio.bass")
local bass_fx = require("aqua.audio.bass_fx")
local Audio = require("aqua.audio.Audio")

local SampleStream = Audio:new()

SampleStream.construct = function(self)
	-- self.proxy = newproxy(true)
	-- getmetatable(self.proxy).__gc = function()
		-- bass.BASS_StreamFree(self.channel)
	-- end
	
	self.channel = bass.BASS_StreamCreateFile(true, self.soundData.dataPointer, 0, self.soundData.fileData:getSize(), 0x200000)
	-- print(bass.BASS_ErrorGetCode())
	self.channel = bass_fx.BASS_FX_TempoCreate(self.channel, 0x10000)
	-- bass.BASS_ChannelSetAttribute(self.channel, 0x10000, 50)
end

SampleStream.free = function(self)
	-- bass.BASS_StreamFree(self.channel)
end

return SampleStream
