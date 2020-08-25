local safelib = require("aqua.safelib")
local cdef = require("aqua.cdef")
local ffi = require("ffi")

local bass = {}

local _bass = assert(safelib.load("bass", true))

_bass.BASS_Init(-1, 44100, 0, nil, nil)

setmetatable(bass, {
	__index = _bass
})

bass.files = {}
bass.fileCounter = 0
bass.addFile = function(file)
	bass.fileCounter = bass.fileCounter + 1
	bass.files[bass.fileCounter] = file
	return bass.fileCounter
end
bass.removeFile = function(id)
	bass.files[id] = nil
end

local fileProcsTable = {}
bass.fileProcsTable = fileProcsTable

local idUser = ffi.new("struct {int32_t* user;}")

fileProcsTable.closeProc = function(user)
	idUser.user = user
	bass.files[idUser.user[0]]:close()
end
fileProcsTable.lengthProc = function(user)
	idUser.user = user
	return bass.files[idUser.user[0]]:getSize()
end
fileProcsTable.readProc = function(buffer, length, user)
	idUser.user = user
	local contents, size = bass.files[idUser.user[0]]:read(length)
	ffi.copy(buffer, contents, size)
	return size
end
fileProcsTable.seekProc = function(offset, user)
	idUser.user = user
	return bass.files[idUser.user[0]]:seek(offset)
end

local fileProcs = ffi.new("BASS_FILEPROCS", {
	fileProcsTable.closeProc,
	fileProcsTable.lengthProc,
	fileProcsTable.readProc,
	fileProcsTable.seekProc
})
bass.fileProcs = fileProcs

return bass
