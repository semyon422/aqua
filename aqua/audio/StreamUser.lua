local ffi = require("ffi")
local loveffi = require("aqua.loveffi")
local bass = require("aqua.audio.bass")
local bass_fx = require("aqua.audio.bass_fx")
local Stream = require("aqua.audio.Stream")
local Audio = require("aqua.audio.Audio")

local StreamUser = Audio:new()

StreamUser.free = function(self)
	return Stream.free(self)
end

local close = function(userdata)
	-- local file = loveffi.pointerToObject(userdata, 5, "File")
	-- return file:close()
end
local length = function(userdata)
	-- local file = loveffi.pointerToObject(userdata, 5, "File")
	-- print(file:getFilename())
	-- return file:getSize()
	return 2^20
end
local read = function(buffer, length, userdata)
	-- local file = loveffi.pointerToObject(userdata, 5, "File")
	-- local contents, size = file:read(length)
		-- if type(contents) == "number" then
			-- print(contents, size, type(file))
			-- return 0
		-- end
	-- ffi.copy(buffer, contents)
	-- return size
	return 0
end
local seek = function(offset, userdata)
	-- local file = loveffi.pointerToObject(userdata, 5, "File")
	-- return file:seek(offset)
	return true
end

local streams = {}
-- StreamUser.construct = function(self)
	-- streams[self] = self
	-- self.file = love.filesystem.newFile(self.path)
	-- self.file:open("r")
	
	-- self.pointer, self.type, self.typeEnum = loveffi.objectToPointer(self.file)
	-- print("open", self.path)
	
	-- self.fileprocs = ffi.new("BASS_FILEPROCS[1]")
	-- self.fileprocs[0].close = close
	-- self.fileprocs[0].length = length
	-- self.fileprocs[0].read = read
	-- self.fileprocs[0].seek = seek
	
	-- self.channel = bass.BASS_StreamCreateFileUser(0, 0, self.fileprocs, self.pointer)
-- end

-- return StreamUser


StreamUser.construct = function(self)
	streams[self] = self
	self.file = love.filesystem.newFile(self.path)
	self.file:open("r")
	print("open", self.path)
	
	local file = self.file
	self.close = function(user)
		-- print("close")
	end
	self.length = function(user)
		-- print("length")
		return file:getSize()
	end
	self.read = function(buffer, length, user)
		local contents, size = file:read(length)
		-- print("read")
		-- if type(contents) == "number" then
			-- print(contents, size, type(file))
			-- return 0
		-- end
		ffi.copy(buffer, contents)
		return size
	end
	self.seek = function(offset, user)
		-- print("seek")
		-- return file:seek(offset)
		return true
	end
	
	self.fileprocs = ffi.new("BASS_FILEPROCS[1]")
	self.fileprocs[0].close = self.close
	self.fileprocs[0].length = self.length
	self.fileprocs[0].read = self.read
	self.fileprocs[0].seek = self.seek
	
	self.channel = bass.BASS_StreamCreateFileUser(0, 0, self.fileprocs, nil)
end

return StreamUser
