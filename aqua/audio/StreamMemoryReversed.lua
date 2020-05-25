local ffi = require("ffi")
local byte = require("byte")
local loveffi = require("aqua.loveffi")
local bass = require("aqua.audio.bass")
local bass_fx = require("aqua.audio.bass_fx")
local StreamFile = require("aqua.audio.StreamFile")

local StreamMemoryReversed = StreamFile:new()

StreamMemoryReversed.construct = function(self)
	if not self.byteBuffer then
		local file = love.filesystem.newFile(self.path)
		file:open("r")

		self.byteBuffer = byte.buffer(file:read(), 0, nil, true)
		file:close()
	end

	self.channel = bass.BASS_StreamCreateFile(true, self.byteBuffer.pointer, 0, self.byteBuffer.length, 0x200000)
	self.channel = bass_fx.BASS_FX_ReverseCreate(self.channel, self:getLength(), 0x10000)
end

return StreamMemoryReversed
