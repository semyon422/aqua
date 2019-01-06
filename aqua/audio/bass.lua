local ffi = require("ffi")

ffi.cdef([[
typedef signed char __int8_t;
typedef unsigned char __uint8_t;
typedef short int __int16_t;
typedef short unsigned int __uint16_t;
typedef int __int32_t;
typedef unsigned int __uint32_t;
typedef long int __int64_t;
typedef long unsigned int __uint64_t;
typedef signed char __int_least8_t;
typedef unsigned char __uint_least8_t;
typedef short int __int_least16_t;
typedef short unsigned int __uint_least16_t;
typedef int __int_least32_t;
typedef unsigned int __uint_least32_t;
typedef long int __int_least64_t;
typedef long unsigned int __uint_least64_t;
typedef long int __intmax_t;
typedef long unsigned int __uintmax_t;
typedef long int __intptr_t;
typedef long unsigned int __uintptr_t;
typedef __int8_t int8_t ;
typedef __uint8_t uint8_t ;
typedef __int16_t int16_t ;
typedef __uint16_t uint16_t ;
typedef __int32_t int32_t ;
typedef __uint32_t uint32_t ;
typedef __int64_t int64_t ;
typedef __uint64_t uint64_t ;
typedef __intmax_t intmax_t;
typedef __uintmax_t uintmax_t;
typedef __intptr_t intptr_t;
typedef __uintptr_t uintptr_t;
typedef __int_least8_t int_least8_t;
typedef __uint_least8_t uint_least8_t;
typedef __int_least16_t int_least16_t;
typedef __uint_least16_t uint_least16_t;
typedef __int_least32_t int_least32_t;
typedef __uint_least32_t uint_least32_t;
typedef __int_least64_t int_least64_t;
typedef __uint_least64_t uint_least64_t;
typedef signed char int_fast8_t;
typedef unsigned char uint_fast8_t;
typedef long int int_fast16_t;
typedef long unsigned int uint_fast16_t;
typedef long int int_fast32_t;
typedef long unsigned int uint_fast32_t;
typedef long int int_fast64_t;
typedef long unsigned int uint_fast64_t;
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
const char *name;
const char *driver;
DWORD flags;
} BASS_DEVICEINFO;
typedef struct {
DWORD flags;
DWORD hwsize;
DWORD hwfree;
DWORD freesam;
DWORD free3d;
DWORD minrate;
DWORD maxrate;
BOOL eax;
DWORD minbuf;
DWORD dsver;
DWORD latency;
DWORD initflags;
DWORD speakers;
DWORD freq;
} BASS_INFO;
typedef struct {
DWORD flags;
DWORD formats;
DWORD inputs;
BOOL singlein;
DWORD freq;
} BASS_RECORDINFO;
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
DWORD ctype;
const char *name;
const char *exts;
} BASS_PLUGINFORM;
typedef struct {
DWORD version;
DWORD formatc;
const BASS_PLUGINFORM *formats;
} BASS_PLUGININFO;
typedef struct BASS_3DVECTOR {
float x;
float y;
float z;
} BASS_3DVECTOR;
enum
{
EAX_ENVIRONMENT_GENERIC,
EAX_ENVIRONMENT_PADDEDCELL,
EAX_ENVIRONMENT_ROOM,
EAX_ENVIRONMENT_BATHROOM,
EAX_ENVIRONMENT_LIVINGROOM,
EAX_ENVIRONMENT_STONEROOM,
EAX_ENVIRONMENT_AUDITORIUM,
EAX_ENVIRONMENT_CONCERTHALL,
EAX_ENVIRONMENT_CAVE,
EAX_ENVIRONMENT_ARENA,
EAX_ENVIRONMENT_HANGAR,
EAX_ENVIRONMENT_CARPETEDHALLWAY,
EAX_ENVIRONMENT_HALLWAY,
EAX_ENVIRONMENT_STONECORRIDOR,
EAX_ENVIRONMENT_ALLEY,
EAX_ENVIRONMENT_FOREST,
EAX_ENVIRONMENT_CITY,
EAX_ENVIRONMENT_MOUNTAINS,
EAX_ENVIRONMENT_QUARRY,
EAX_ENVIRONMENT_PLAIN,
EAX_ENVIRONMENT_PARKINGLOT,
EAX_ENVIRONMENT_SEWERPIPE,
EAX_ENVIRONMENT_UNDERWATER,
EAX_ENVIRONMENT_DRUGGED,
EAX_ENVIRONMENT_DIZZY,
EAX_ENVIRONMENT_PSYCHOTIC,
EAX_ENVIRONMENT_COUNT
};
typedef DWORD ( STREAMPROC)(HSTREAM handle, void *buffer, DWORD length, void *user);
typedef void ( FILECLOSEPROC)(void *user);
typedef QWORD ( FILELENPROC)(void *user);
typedef DWORD ( FILEREADPROC)(void *buffer, DWORD length, void *user);
typedef BOOL ( FILESEEKPROC)(QWORD offset, void *user);
typedef struct {
FILECLOSEPROC *close;
FILELENPROC *length;
FILEREADPROC *read;
FILESEEKPROC *seek;
} BASS_FILEPROCS;
typedef void ( DOWNLOADPROC)(const void *buffer, DWORD length, void *user);
typedef void ( SYNCPROC)(HSYNC handle, DWORD channel, DWORD data, void *user);
typedef void ( DSPPROC)(HDSP handle, DWORD channel, void *buffer, DWORD length, void *user);
typedef BOOL ( RECORDPROC)(HRECORD handle, const void *buffer, DWORD length, void *user);
typedef struct {
char id[3];
char title[30];
char artist[30];
char album[30];
char year[4];
char comment[30];
BYTE genre;
} TAG_ID3;
typedef struct {
const char *key;
const void *data;
DWORD length;
} TAG_APE_BINARY;
typedef struct {
char Description[256];
char Originator[32];
char OriginatorReference[32];
char OriginationDate[10];
char OriginationTime[8];
QWORD TimeReference;
WORD Version;
BYTE UMID[64];
BYTE Reserved[190];
char CodingHistory[];
} TAG_BEXT;
typedef struct
{
DWORD dwUsage;
DWORD dwValue;
} TAG_CART_TIMER;
typedef struct
{
char Version[4];
char Title[64];
char Artist[64];
char CutID[64];
char ClientID[64];
char Category[64];
char Classification[64];
char OutCue[64];
char StartDate[10];
char StartTime[8];
char EndDate[10];
char EndTime[8];
char ProducerAppID[64];
char ProducerAppVersion[64];
char UserDef[64];
DWORD dwLevelReference;
TAG_CART_TIMER PostTimer[8];
char Reserved[276];
char URL[1024];
char TagText[];
} TAG_CART;
typedef struct
{
DWORD dwName;
DWORD dwPosition;
DWORD fccChunk;
DWORD dwChunkStart;
DWORD dwBlockStart;
DWORD dwSampleOffset;
} TAG_CUE_POINT;
typedef struct
{
DWORD dwCuePoints;
TAG_CUE_POINT CuePoints[];
} TAG_CUE;
typedef struct
{
DWORD dwIdentifier;
DWORD dwType;
DWORD dwStart;
DWORD dwEnd;
DWORD dwFraction;
DWORD dwPlayCount;
} TAG_SMPL_LOOP;
typedef struct
{
DWORD dwManufacturer;
DWORD dwProduct;
DWORD dwSamplePeriod;
DWORD dwMIDIUnityNote;
DWORD dwMIDIPitchFraction;
DWORD dwSMPTEFormat;
DWORD dwSMPTEOffset;
DWORD cSampleLoops;
DWORD cbSamplerData;
TAG_SMPL_LOOP SampleLoops[];
} TAG_SMPL;
typedef struct {
DWORD ftype;
DWORD atype;
const char *name;
} TAG_CA_CODEC;
typedef struct tWAVEFORMATEX
{
WORD wFormatTag;
WORD nChannels;
DWORD nSamplesPerSec;
DWORD nAvgBytesPerSec;
WORD nBlockAlign;
WORD wBitsPerSample;
WORD cbSize;
} WAVEFORMATEX, *PWAVEFORMATEX, *LPWAVEFORMATEX;
typedef const WAVEFORMATEX *LPCWAVEFORMATEX;
typedef struct {
float fWetDryMix;
float fDepth;
float fFeedback;
float fFrequency;
DWORD lWaveform;
float fDelay;
DWORD lPhase;
} BASS_DX8_CHORUS;
typedef struct {
float fGain;
float fAttack;
float fRelease;
float fThreshold;
float fRatio;
float fPredelay;
} BASS_DX8_COMPRESSOR;
typedef struct {
float fGain;
float fEdge;
float fPostEQCenterFrequency;
float fPostEQBandwidth;
float fPreLowpassCutoff;
} BASS_DX8_DISTORTION;
typedef struct {
float fWetDryMix;
float fFeedback;
float fLeftDelay;
float fRightDelay;
BOOL lPanDelay;
} BASS_DX8_ECHO;
typedef struct {
float fWetDryMix;
float fDepth;
float fFeedback;
float fFrequency;
DWORD lWaveform;
float fDelay;
DWORD lPhase;
} BASS_DX8_FLANGER;
typedef struct {
DWORD dwRateHz;
DWORD dwWaveShape;
} BASS_DX8_GARGLE;
typedef struct {
int lRoom;
int lRoomHF;
float flRoomRolloffFactor;
float flDecayTime;
float flDecayHFRatio;
int lReflections;
float flReflectionsDelay;
int lReverb;
float flReverbDelay;
float flDiffusion;
float flDensity;
float flHFReference;
} BASS_DX8_I3DL2REVERB;
typedef struct {
float fCenter;
float fBandwidth;
float fGain;
} BASS_DX8_PARAMEQ;
typedef struct {
float fInGain;
float fReverbMix;
float fReverbTime;
float fHighFreqRTRatio;
} BASS_DX8_REVERB;
typedef struct {
float fTarget;
float fCurrent;
float fTime;
DWORD lCurve;
} BASS_FX_VOLUME_PARAM;
typedef void ( IOSNOTIFYPROC)(DWORD status);
BOOL BASS_SetConfig(DWORD option, DWORD value);
DWORD BASS_GetConfig(DWORD option);
BOOL BASS_SetConfigPtr(DWORD option, const void *value);
void * BASS_GetConfigPtr(DWORD option);
DWORD BASS_GetVersion();
int BASS_ErrorGetCode();
BOOL BASS_GetDeviceInfo(DWORD device, BASS_DEVICEINFO *info);
BOOL BASS_Init(int device, DWORD freq, DWORD flags, void *win, void *dsguid);
BOOL BASS_SetDevice(DWORD device);
DWORD BASS_GetDevice();
BOOL BASS_Free();
BOOL BASS_GetInfo(BASS_INFO *info);
BOOL BASS_Update(DWORD length);
float BASS_GetCPU();
BOOL BASS_Start();
BOOL BASS_Stop();
BOOL BASS_Pause();
BOOL BASS_SetVolume(float volume);
float BASS_GetVolume();
HPLUGIN BASS_PluginLoad(const char *file, DWORD flags);
BOOL BASS_PluginFree(HPLUGIN handle);
const BASS_PLUGININFO * BASS_PluginGetInfo(HPLUGIN handle);
BOOL BASS_Set3DFactors(float distf, float rollf, float doppf);
BOOL BASS_Get3DFactors(float *distf, float *rollf, float *doppf);
BOOL BASS_Set3DPosition(const BASS_3DVECTOR *pos, const BASS_3DVECTOR *vel, const BASS_3DVECTOR *front, const BASS_3DVECTOR *top);
BOOL BASS_Get3DPosition(BASS_3DVECTOR *pos, BASS_3DVECTOR *vel, BASS_3DVECTOR *front, BASS_3DVECTOR *top);
void BASS_Apply3D();
HMUSIC BASS_MusicLoad(BOOL mem, const void *file, QWORD offset, DWORD length, DWORD flags, DWORD freq);
BOOL BASS_MusicFree(HMUSIC handle);
HSAMPLE BASS_SampleLoad(BOOL mem, const void *file, QWORD offset, DWORD length, DWORD max, DWORD flags);
HSAMPLE BASS_SampleCreate(DWORD length, DWORD freq, DWORD chans, DWORD max, DWORD flags);
BOOL BASS_SampleFree(HSAMPLE handle);
BOOL BASS_SampleSetData(HSAMPLE handle, const void *buffer);
BOOL BASS_SampleGetData(HSAMPLE handle, void *buffer);
BOOL BASS_SampleGetInfo(HSAMPLE handle, BASS_SAMPLE *info);
BOOL BASS_SampleSetInfo(HSAMPLE handle, const BASS_SAMPLE *info);
HCHANNEL BASS_SampleGetChannel(HSAMPLE handle, BOOL onlynew);
DWORD BASS_SampleGetChannels(HSAMPLE handle, HCHANNEL *channels);
BOOL BASS_SampleStop(HSAMPLE handle);
HSTREAM BASS_StreamCreate(DWORD freq, DWORD chans, DWORD flags, STREAMPROC *proc, void *user);
HSTREAM BASS_StreamCreateFile(BOOL mem, const void *file, QWORD offset, QWORD length, DWORD flags);
HSTREAM BASS_StreamCreateURL(const char *url, DWORD offset, DWORD flags, DOWNLOADPROC *proc, void *user);
HSTREAM BASS_StreamCreateFileUser(DWORD system, DWORD flags, const BASS_FILEPROCS *proc, void *user);
BOOL BASS_StreamFree(HSTREAM handle);
QWORD BASS_StreamGetFilePosition(HSTREAM handle, DWORD mode);
DWORD BASS_StreamPutData(HSTREAM handle, const void *buffer, DWORD length);
DWORD BASS_StreamPutFileData(HSTREAM handle, const void *buffer, DWORD length);
BOOL BASS_RecordGetDeviceInfo(DWORD device, BASS_DEVICEINFO *info);
BOOL BASS_RecordInit(int device);
BOOL BASS_RecordSetDevice(DWORD device);
DWORD BASS_RecordGetDevice();
BOOL BASS_RecordFree();
BOOL BASS_RecordGetInfo(BASS_RECORDINFO *info);
const char * BASS_RecordGetInputName(int input);
BOOL BASS_RecordSetInput(int input, DWORD flags, float volume);
DWORD BASS_RecordGetInput(int input, float *volume);
HRECORD BASS_RecordStart(DWORD freq, DWORD chans, DWORD flags, RECORDPROC *proc, void *user);
double BASS_ChannelBytes2Seconds(DWORD handle, QWORD pos);
QWORD BASS_ChannelSeconds2Bytes(DWORD handle, double pos);
DWORD BASS_ChannelGetDevice(DWORD handle);
BOOL BASS_ChannelSetDevice(DWORD handle, DWORD device);
DWORD BASS_ChannelIsActive(DWORD handle);
BOOL BASS_ChannelGetInfo(DWORD handle, BASS_CHANNELINFO *info);
const char * BASS_ChannelGetTags(DWORD handle, DWORD tags);
DWORD BASS_ChannelFlags(DWORD handle, DWORD flags, DWORD mask);
BOOL BASS_ChannelUpdate(DWORD handle, DWORD length);
BOOL BASS_ChannelLock(DWORD handle, BOOL lock);
BOOL BASS_ChannelPlay(DWORD handle, BOOL restart);
BOOL BASS_ChannelStop(DWORD handle);
BOOL BASS_ChannelPause(DWORD handle);
BOOL BASS_ChannelSetAttribute(DWORD handle, DWORD attrib, float value);
BOOL BASS_ChannelGetAttribute(DWORD handle, DWORD attrib, float *value);
BOOL BASS_ChannelSlideAttribute(DWORD handle, DWORD attrib, float value, DWORD time);
BOOL BASS_ChannelIsSliding(DWORD handle, DWORD attrib);
BOOL BASS_ChannelSetAttributeEx(DWORD handle, DWORD attrib, void *value, DWORD size);
DWORD BASS_ChannelGetAttributeEx(DWORD handle, DWORD attrib, void *value, DWORD size);
BOOL BASS_ChannelSet3DAttributes(DWORD handle, int mode, float min, float max, int iangle, int oangle, float outvol);
BOOL BASS_ChannelGet3DAttributes(DWORD handle, DWORD *mode, float *min, float *max, DWORD *iangle, DWORD *oangle, float *outvol);
BOOL BASS_ChannelSet3DPosition(DWORD handle, const BASS_3DVECTOR *pos, const BASS_3DVECTOR *orient, const BASS_3DVECTOR *vel);
BOOL BASS_ChannelGet3DPosition(DWORD handle, BASS_3DVECTOR *pos, BASS_3DVECTOR *orient, BASS_3DVECTOR *vel);
QWORD BASS_ChannelGetLength(DWORD handle, DWORD mode);
BOOL BASS_ChannelSetPosition(DWORD handle, QWORD pos, DWORD mode);
QWORD BASS_ChannelGetPosition(DWORD handle, DWORD mode);
DWORD BASS_ChannelGetLevel(DWORD handle);
BOOL BASS_ChannelGetLevelEx(DWORD handle, float *levels, float length, DWORD flags);
DWORD BASS_ChannelGetData(DWORD handle, void *buffer, DWORD length);
HSYNC BASS_ChannelSetSync(DWORD handle, DWORD type, QWORD param, SYNCPROC *proc, void *user);
BOOL BASS_ChannelRemoveSync(DWORD handle, HSYNC sync);
HDSP BASS_ChannelSetDSP(DWORD handle, DSPPROC *proc, void *user, int priority);
BOOL BASS_ChannelRemoveDSP(DWORD handle, HDSP dsp);
BOOL BASS_ChannelSetLink(DWORD handle, DWORD chan);
BOOL BASS_ChannelRemoveLink(DWORD handle, DWORD chan);
HFX BASS_ChannelSetFX(DWORD handle, DWORD type, int priority);
BOOL BASS_ChannelRemoveFX(DWORD handle, HFX fx);
BOOL BASS_FXSetParameters(HFX handle, const void *params);
BOOL BASS_FXGetParameters(HFX handle, void *params);
BOOL BASS_FXReset(HFX handle);
BOOL BASS_FXSetPriority(HFX handle, int priority);
]])

local bass = {}

local _bass = ffi.load("bass")
_bass.BASS_Init(-1, 44100, 0, nil, nil)

setmetatable(bass, {
	__index = _bass
})

return bass