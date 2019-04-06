local ffi = require("ffi")
local cdef = require("aqua.cdef")

local bass = {}

local _bass = ffi.load("bass")
_bass.BASS_Init(-1, 44100, 0, nil, nil)

setmetatable(bass, {
	__index = _bass
})

return bass