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

	BOOL BASS_Mixer_ChannelSetPosition(
		DWORD handle,
		QWORD pos,
		DWORD mode
	);
]]

return setmetatable({}, {__index = ffi.load("bassmix", true)})
