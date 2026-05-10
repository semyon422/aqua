local ffi = require("ffi")

ffi.cdef [[
	HSTREAM BASS_FX_TempoCreate(DWORD chan, DWORD flags);
	HSTREAM BASS_FX_ReverseCreate(DWORD chan, float dec_block, DWORD flags);
]]

---@class ffi.namespace*
---@field BASS_FX_TempoCreate fun(chan: integer, flags: integer): integer
---@field BASS_FX_ReverseCreate fun(chan: integer, dec_block: number, flags: integer): integer

return setmetatable({}, {__index = ffi.load("bass_fx", true)})
