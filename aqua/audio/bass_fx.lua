local ffi = require("ffi")

ffi.cdef([[
DWORD BASS_FX_GetVersion();
enum {
BASS_FX_BFX_ROTATE = 0x10000,
BASS_FX_BFX_ECHO,
BASS_FX_BFX_FLANGER,
BASS_FX_BFX_VOLUME,
BASS_FX_BFX_PEAKEQ,
BASS_FX_BFX_REVERB,
BASS_FX_BFX_LPF,
BASS_FX_BFX_MIX,
BASS_FX_BFX_DAMP,
BASS_FX_BFX_AUTOWAH,
BASS_FX_BFX_ECHO2,
BASS_FX_BFX_PHASER,
BASS_FX_BFX_ECHO3,
BASS_FX_BFX_CHORUS,
BASS_FX_BFX_APF,
BASS_FX_BFX_COMPRESSOR,
BASS_FX_BFX_DISTORTION,
BASS_FX_BFX_COMPRESSOR2,
BASS_FX_BFX_VOLUME_ENV,
BASS_FX_BFX_BQF,
BASS_FX_BFX_ECHO4,
BASS_FX_BFX_PITCHSHIFT,
BASS_FX_BFX_FREEVERB
};
typedef struct {
float fRate;
int lChannel;
} BASS_BFX_ROTATE;
typedef struct {
float fLevel;
int lDelay;
} BASS_BFX_ECHO;
typedef struct {
float fWetDry;
float fSpeed;
int lChannel;
} BASS_BFX_FLANGER;
typedef struct {
int lChannel;
float fVolume;
} BASS_BFX_VOLUME;
typedef struct {
int lBand;
float fBandwidth;
float fQ;
float fCenter;
float fGain;
int lChannel;
} BASS_BFX_PEAKEQ;
typedef struct {
float fLevel;
int lDelay;
} BASS_BFX_REVERB;
typedef struct {
float fResonance;
float fCutOffFreq;
int lChannel;
} BASS_BFX_LPF;
typedef struct {
const int *lChannel;
} BASS_BFX_MIX;
typedef struct {
float fTarget;
float fQuiet;
float fRate;
float fGain;
float fDelay;
int lChannel;
} BASS_BFX_DAMP;
typedef struct {
float fDryMix;
float fWetMix;
float fFeedback;
float fRate;
float fRange;
float fFreq;
int lChannel;
} BASS_BFX_AUTOWAH;
typedef struct {
float fDryMix;
float fWetMix;
float fFeedback;
float fDelay;
int lChannel;
} BASS_BFX_ECHO2;
typedef struct {
float fDryMix;
float fWetMix;
float fFeedback;
float fRate;
float fRange;
float fFreq;
int lChannel;
} BASS_BFX_PHASER;
typedef struct {
float fDryMix;
float fWetMix;
float fDelay;
int lChannel;
} BASS_BFX_ECHO3;
typedef struct {
float fDryMix;
float fWetMix;
float fFeedback;
float fMinSweep;
float fMaxSweep;
float fRate;
int lChannel;
} BASS_BFX_CHORUS;
typedef struct {
float fGain;
float fDelay;
int lChannel;
} BASS_BFX_APF;
typedef struct {
float fThreshold;
float fAttacktime;
float fReleasetime;
int lChannel;
} BASS_BFX_COMPRESSOR;
typedef struct {
float fDrive;
float fDryMix;
float fWetMix;
float fFeedback;
float fVolume;
int lChannel;
} BASS_BFX_DISTORTION;
typedef struct {
float fGain;
float fThreshold;
float fRatio;
float fAttack;
float fRelease;
int lChannel;
} BASS_BFX_COMPRESSOR2;
typedef struct {
int lChannel;
int lNodeCount;
const struct BASS_BFX_ENV_NODE *pNodes;
BOOL bFollow;
} BASS_BFX_VOLUME_ENV;
typedef struct BASS_BFX_ENV_NODE {
double pos;
float val;
} BASS_BFX_ENV_NODE;
enum {
BASS_BFX_BQF_LOWPASS,
BASS_BFX_BQF_HIGHPASS,
BASS_BFX_BQF_BANDPASS,
BASS_BFX_BQF_BANDPASS_Q,
BASS_BFX_BQF_NOTCH,
BASS_BFX_BQF_ALLPASS,
BASS_BFX_BQF_PEAKINGEQ,
BASS_BFX_BQF_LOWSHELF,
BASS_BFX_BQF_HIGHSHELF
};
typedef struct {
int lFilter;
float fCenter;
float fGain;
float fBandwidth;
float fQ;
float fS;
int lChannel;
} BASS_BFX_BQF;
typedef struct {
float fDryMix;
float fWetMix;
float fFeedback;
float fDelay;
BOOL bStereo;
int lChannel;
} BASS_BFX_ECHO4;
typedef struct {
float fPitchShift;
float fSemitones;
long lFFTsize;
long lOsamp;
int lChannel;
} BASS_BFX_PITCHSHIFT;
typedef struct {
float fDryMix;
float fWetMix;
float fRoomSize;
float fDamp;
float fWidth;
DWORD lMode;
int lChannel;
} BASS_BFX_FREEVERB;
enum {
BASS_ATTRIB_TEMPO = 0x10000,
BASS_ATTRIB_TEMPO_PITCH,
BASS_ATTRIB_TEMPO_FREQ
};
enum {
BASS_ATTRIB_TEMPO_OPTION_USE_AA_FILTER = 0x10010,
BASS_ATTRIB_TEMPO_OPTION_AA_FILTER_LENGTH,
BASS_ATTRIB_TEMPO_OPTION_USE_QUICKALGO,
BASS_ATTRIB_TEMPO_OPTION_SEQUENCE_MS,
BASS_ATTRIB_TEMPO_OPTION_SEEKWINDOW_MS,
BASS_ATTRIB_TEMPO_OPTION_OVERLAP_MS,
BASS_ATTRIB_TEMPO_OPTION_PREVENT_CLICK
};
HSTREAM BASS_FX_TempoCreate(DWORD chan, DWORD flags);
DWORD BASS_FX_TempoGetSource(HSTREAM chan);
float BASS_FX_TempoGetRateRatio(HSTREAM chan);
HSTREAM BASS_FX_ReverseCreate(DWORD chan, float dec_block, DWORD flags);
DWORD BASS_FX_ReverseGetSource(HSTREAM chan);
enum {
BASS_FX_BPM_TRAN_X2,
BASS_FX_BPM_TRAN_2FREQ,
BASS_FX_BPM_TRAN_FREQ2,
BASS_FX_BPM_TRAN_2PERCENT,
BASS_FX_BPM_TRAN_PERCENT2
};
typedef void ( BPMPROC)(DWORD chan, float bpm, void *user);
typedef void ( BPMPROGRESSPROC)(DWORD chan, float percent, void *user);
typedef BPMPROGRESSPROC BPMPROCESSPROC;
float BASS_FX_BPM_DecodeGet(DWORD chan, double startSec, double endSec, DWORD minMaxBPM, DWORD flags, BPMPROGRESSPROC *proc, void *user);
BOOL BASS_FX_BPM_CallbackSet(DWORD handle, BPMPROC *proc, double period, DWORD minMaxBPM, DWORD flags, void *user);
BOOL BASS_FX_BPM_CallbackReset(DWORD handle);
float BASS_FX_BPM_Translate(DWORD handle, float val2tran, DWORD trans);
BOOL BASS_FX_BPM_Free(DWORD handle);
typedef void ( BPMBEATPROC)(DWORD chan, double beatpos, void *user);
BOOL BASS_FX_BPM_BeatCallbackSet(DWORD handle, BPMBEATPROC *proc, void *user);
BOOL BASS_FX_BPM_BeatCallbackReset(DWORD handle);
BOOL BASS_FX_BPM_BeatDecodeGet(DWORD chan, double startSec, double endSec, DWORD flags, BPMBEATPROC *proc, void *user);
BOOL BASS_FX_BPM_BeatSetParameters(DWORD handle, float bandwidth, float centerfreq, float beat_rtime);
BOOL BASS_FX_BPM_BeatGetParameters(DWORD handle, float *bandwidth, float *centerfreq, float *beat_rtime);
BOOL BASS_FX_BPM_BeatFree(DWORD handle);
]])

local bass_fx = {}

local _bass_fx = ffi.load("bass_fx")

setmetatable(bass_fx, {
	__index = _bass_fx
})

local bass = require("aqua.audio.bass")

bass.BASS_PluginLoad("bin64/bass_fx.dll", 0)

return bass_fx