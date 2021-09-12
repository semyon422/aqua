local dl = require("aqua.dl")
local ffi = require("ffi")

ffi.cdef([[
HSTREAM BASS_FX_TempoCreate(DWORD chan, DWORD flags);
HSTREAM BASS_FX_ReverseCreate(DWORD chan, float dec_block, DWORD flags);
]])

local bass_fx = {}

local _bass_fx = ffi.load(dl.get("bass_fx"), true)

setmetatable(bass_fx, {
	__index = _bass_fx
})

local bass = require("aqua.audio.bass")

bass.BASS_PluginLoad(dl.get("bass_fx"), 0)

return bass_fx
