local ffi = require("ffi")

ffi.cdef([[
typedef uint8_t BYTE;
typedef uint16_t WORD;
typedef uint32_t DWORD;
typedef uint64_t QWORD;
typedef int BOOL;
typedef DWORD HMUSIC;
typedef DWORD HSAMPLE;
typedef DWORD HCHANNEL;
typedef DWORD HSTREAM;
typedef DWORD HRECORD;
typedef DWORD HSYNC;
typedef DWORD HDSP;
typedef DWORD HFX;
typedef DWORD HPLUGIN;

typedef struct {
DWORD freq;
DWORD chans;
DWORD flags;
DWORD ctype;
DWORD origres;
HPLUGIN plugin;
HSAMPLE sample;
const char *filename;
} BASS_CHANNELINFO;

typedef struct {
DWORD freq;
float volume;
float pan;
DWORD flags;
DWORD length;
DWORD max;
DWORD origres;
DWORD chans;
DWORD mingap;
DWORD mode3d;
float mindist;
float maxdist;
DWORD iangle;
DWORD oangle;
float outvol;
DWORD vam;
DWORD priority;
} BASS_SAMPLE;

BOOL BASS_Init(int device, DWORD freq, DWORD flags, void *win, void *dsguid);
BOOL BASS_SampleGetInfo(HSAMPLE handle, BASS_SAMPLE *info);
BOOL BASS_SampleGetData(HSAMPLE handle, void *buffer);
BOOL BASS_SampleSetData(HSAMPLE handle, const void *buffer);
QWORD BASS_ChannelSeconds2Bytes(DWORD handle, double pos);
QWORD BASS_ChannelGetPosition(DWORD handle, DWORD mode);
BOOL BASS_ChannelGetInfo(DWORD handle, BASS_CHANNELINFO *info);
QWORD BASS_ChannelGetLength(DWORD handle, DWORD mode);
HSAMPLE BASS_SampleLoad(BOOL mem, const void *file, QWORD offset, DWORD length, DWORD max, DWORD flags);
BOOL BASS_SampleFree(HSAMPLE handle);
BOOL BASS_ChannelFree(DWORD handle);
BOOL BASS_ChannelSetAttribute(DWORD handle, DWORD attrib, float value);
HSTREAM BASS_StreamCreateFile(BOOL mem, const void *file, QWORD offset, QWORD length, DWORD flags);
HCHANNEL BASS_SampleGetChannel(HSAMPLE handle, BOOL onlynew);
BOOL BASS_ChannelPlay(DWORD handle, BOOL restart);
BOOL BASS_ChannelStop(DWORD handle);
BOOL BASS_ChannelPause(DWORD handle);
DWORD BASS_ChannelIsActive(DWORD handle);
double BASS_ChannelBytes2Seconds(DWORD handle, QWORD pos);
BOOL BASS_ChannelSetPosition(DWORD handle, QWORD pos, DWORD mode);
HPLUGIN BASS_PluginLoad(const char *file, DWORD flags);
DWORD BASS_SampleGetChannels(HSAMPLE handle, HCHANNEL *channels);
int BASS_ErrorGetCode();
]])

local bass = ffi.load("bass", true)
local _bass = newproxy(true)

local mt = getmetatable(_bass)
mt.__index = bass

local Plugins = {
	Windows = {"bassopus.dll"},
	Linux = {"libbassopus.so"},
}

if bass.BASS_Init(-1, 44100, 0, nil, nil) ~= 0 then
	mt.__gc = function()
		assert(bass.BASS_Free() ~= 0, "BASS_Free failed")
		assert(bass.BASS_PluginFree(0) ~= 0, "BASS_PluginFree failed")
	end

	local plugins = Plugins[jit.os]
	if not plugins then
		return
	end

	for _, file in ipairs(plugins) do
		bass.BASS_PluginLoad(file, 0)
		-- assert(bass.BASS_PluginLoad(file, 0) ~= 0, ("BASS_PluginLoad(%q) failed"):format(file))
	end
end

return _bass
