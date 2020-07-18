local safelib = require("aqua.safelib")
local cdef = require("aqua.cdef")

local bass = {}

local _bass = assert(safelib.load("bass", true))

_bass.BASS_Init(-1, 44100, 0, nil, nil)

setmetatable(bass, {
	__index = _bass
})

return bass
