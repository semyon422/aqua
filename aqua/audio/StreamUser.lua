local ffi = require("ffi")
local bass = require("aqua.audio.bass")
local Stream = require("aqua.audio.Stream")

local StreamUser = Stream:new()

StreamUser.construct = function(self)
	self.file = love.filesystem.newFile(self.path, "r")
	self.idPointer = ffi.new("int32_t[1]")
	self.idPointer[0] = bass.addFile(self.file)
	self.channel = bass.BASS_StreamCreateFileUser(1, 0, bass.fileProcs, self.idPointer)
end

StreamUser.free = function(self)
	bass.removeFile(self.idPointer[0])
	Stream.free(self)
end

return StreamUser
