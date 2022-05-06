local dl = require("aqua.dl")
local ffi = require("ffi")

ffi.cdef([[
HSTREAM BASS_FX_TempoCreate(DWORD chan, DWORD flags);
HSTREAM BASS_FX_ReverseCreate(DWORD chan, float dec_block, DWORD flags);
]])

return setmetatable({}, {__index = ffi.load(dl.get("bass_fx"), true)})
