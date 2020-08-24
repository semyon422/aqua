local ffi = require("ffi")
local bass = require("aqua.audio.bass")
local Stream = require("aqua.audio.Stream")

local StreamUser = Stream:new()

StreamUser.construct = function(self)
	self.file = love.filesystem.newFile(self.path, "r")
	self.closeProc = function(user)
		self.file:close()
	end
	self.lengthProc = function(user)
		return self.file:getSize()
	end
	self.readProc = function(buffer, length, user)
		local contents, size = self.file:read(length)
		ffi.copy(buffer, contents, size)
		return size
	end
	self.seekProc = function(offset, user)
		return self.file:seek(offset)
	end
	local procs = ffi.new("BASS_FILEPROCS", {self.closeProc, self.lengthProc, self.readProc, self.seekProc})
	self.channel = bass.BASS_StreamCreateFileUser(1, 0, procs, nil)
end

return StreamUser
