local safelib = require("aqua.safelib")
local cdef = require("aqua.cdef")

local bass_fx = {}

local _bass_fx = assert(safelib.load("bass_fx", true))

setmetatable(bass_fx, {
	__index = _bass_fx
})

local bass = require("aqua.audio.bass")

bass.BASS_PluginLoad(safelib.get("bass_fx"), 0)

return bass_fx
