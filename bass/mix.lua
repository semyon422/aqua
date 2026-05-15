local ffi = require("ffi")

ffi.cdef [[
	HSTREAM BASS_Mixer_StreamCreate(
		DWORD freq,
		DWORD chans,
		DWORD flags
	);
	
	BOOL BASS_Mixer_StreamAddChannel(
		HSTREAM handle,
		DWORD channel,
		DWORD flags
	);

	BOOL BASS_Mixer_StreamAddChannelEx(
		HSTREAM handle,
		DWORD channel,
		DWORD flags,
		QWORD start,
		QWORD length
	);

	QWORD BASS_Mixer_ChannelGetPosition(
		DWORD handle,
		DWORD mode
	);

	DWORD BASS_Mixer_ChannelIsActive(
		DWORD handle
	);

	BOOL BASS_Mixer_ChannelRemove(
		DWORD handle
	);

	BOOL BASS_Mixer_ChannelSetPosition(
		DWORD handle,
		QWORD pos,
		DWORD mode
	);
]]

---@class ffi.namespace*
---@field BASS_Mixer_StreamCreate fun(freq: integer, chans: integer, flags: integer): integer
---@field BASS_Mixer_StreamAddChannel fun(handle: integer, channel: integer, flags: integer): integer
---@field BASS_Mixer_StreamAddChannelEx fun(handle: integer, channel: integer, flags: integer, start: integer, length: integer): integer
---@field BASS_Mixer_ChannelGetPosition fun(handle: integer, mode: integer): integer
---@field BASS_Mixer_ChannelIsActive fun(handle: integer): integer
---@field BASS_Mixer_ChannelRemove fun(handle: integer): integer
---@field BASS_Mixer_ChannelSetPosition fun(handle: integer, pos: integer, mode: integer): integer

return setmetatable({}, {__index = ffi.load("bassmix", true)})
