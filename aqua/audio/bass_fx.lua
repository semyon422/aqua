local dl = require("aqua.dl")
local cdef = require("aqua.cdef")
local ffi = require("ffi")

local bass_fx = {}

local _bass_fx = ffi.load(dl.get("bass_fx"), true)

setmetatable(bass_fx, {
	__index = _bass_fx
})

local bass = require("aqua.audio.bass")

bass.BASS_PluginLoad(dl.get("bass_fx"), 0)

return bass_fx
