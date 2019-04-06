local ffi = require("ffi")
local cdef = require("aqua.cdef")

local bass_fx = {}

local _bass_fx = ffi.load("bass_fx")

setmetatable(bass_fx, {
	__index = _bass_fx
})

local bass = require("aqua.audio.bass")

bass.BASS_PluginLoad("bin64/bass_fx.dll", 0)

return bass_fx