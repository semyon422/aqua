return {
	BASS_SAMPLE_8BITS = 1, -- 8 bit
	BASS_SAMPLE_FLOAT = 256, -- 32 bit floating-point
	BASS_SAMPLE_MONO = 2, -- mono
	BASS_SAMPLE_LOOP = 4, -- looped
	BASS_SAMPLE_3D = 8, -- 3D functionality
	BASS_SAMPLE_SOFTWARE = 16, -- unused
	BASS_SAMPLE_MUTEMAX = 32, -- mute at max distance (3D only)
	BASS_SAMPLE_VAM = 64, -- unused
	BASS_SAMPLE_FX = 128, -- unused
	BASS_SAMPLE_OVER_VOL = 0x10000, -- override lowest volume
	BASS_SAMPLE_OVER_POS = 0x20000, -- override longest playing
	BASS_SAMPLE_OVER_DIST = 0x30000, -- override furthest from listener (3D only)

	BASS_STREAM_PRESCAN = 0x20000, -- scan file for accurate seeking and length
	BASS_STREAM_AUTOFREE = 0x40000, -- automatically free the stream when it stops/ends
	BASS_STREAM_RESTRATE = 0x80000, -- restrict the download rate of internet file stream
	BASS_STREAM_BLOCK = 0x100000, -- download internet file stream in small blocks
	BASS_STREAM_DECODE = 0x200000, -- don't play the stream, only decode
	BASS_STREAM_STATUS = 0x800000, -- give server status info (HTTP/ICY tags) in DOWNLOADPROC

	BASS_ASYNCFILE = 0x40000000, -- read file asynchronously
	BASS_UNICODE = 0x80000000, -- UTF-16

	-- BASS_SampleGetChannel flags
	BASS_SAMCHAN_NEW = 1, -- get a new playback channel
	BASS_SAMCHAN_STREAM = 2, -- create a stream

	-- BASS_ChannelIsActive return values
	BASS_ACTIVE_STOPPED = 0,
	BASS_ACTIVE_PLAYING = 1,
	BASS_ACTIVE_STALLED = 2,
	BASS_ACTIVE_PAUSED = 3,
	BASS_ACTIVE_PAUSED_DEVICE = 4,

	-- Channel attributes
	BASS_ATTRIB_FREQ = 1,
	BASS_ATTRIB_VOL = 2,
	BASS_ATTRIB_PAN = 3,
	BASS_ATTRIB_EAXMIX = 4,
	BASS_ATTRIB_NOBUFFER = 5,
	BASS_ATTRIB_VBR = 6,
	BASS_ATTRIB_CPU = 7,
	BASS_ATTRIB_SRC = 8,
	BASS_ATTRIB_NET_RESUME = 9,
	BASS_ATTRIB_SCANINFO = 10,
	BASS_ATTRIB_NORAMP = 11,
	BASS_ATTRIB_BITRATE = 12,
	BASS_ATTRIB_BUFFER = 13,
	BASS_ATTRIB_GRANULE = 14,
	BASS_ATTRIB_USER = 15,
	BASS_ATTRIB_TAIL = 16,
	BASS_ATTRIB_PUSH_LIMIT = 17,
	BASS_ATTRIB_DOWNLOADPROC = 18,
	BASS_ATTRIB_VOLDSP = 19,
	BASS_ATTRIB_VOLDSP_PRIORITY = 20,
	BASS_ATTRIB_MUSIC_AMPLIFY = 0x100,
	BASS_ATTRIB_MUSIC_PANSEP = 0x101,
	BASS_ATTRIB_MUSIC_PSCALER = 0x102,
	BASS_ATTRIB_MUSIC_BPM = 0x103,
	BASS_ATTRIB_MUSIC_SPEED = 0x104,
	BASS_ATTRIB_MUSIC_VOL_GLOBAL = 0x105,
	BASS_ATTRIB_MUSIC_ACTIVE = 0x106,
	BASS_ATTRIB_MUSIC_VOL_CHAN = 0x200, -- + channel #
	BASS_ATTRIB_MUSIC_VOL_INST = 0x300, -- + instrument #

	-- BASS_ChannelGetLength/GetPosition/SetPosition modes
	BASS_POS_BYTE = 0, -- byte position
	BASS_POS_MUSIC_ORDER = 1, -- order.row position, MAKELONG(order,row)
	BASS_POS_OGG = 3, -- OGG bitstream number
	BASS_POS_END = 0x10, -- trimmed end position
	BASS_POS_LOOP = 0x11, -- loop start positiom
	BASS_POS_FLUSH = 0x1000000, -- flag: flush decoder/FX buffers
	BASS_POS_RESET = 0x2000000, -- flag: reset user file buffers
	BASS_POS_RELATIVE = 0x4000000, -- flag: seek relative to the current position
	BASS_POS_INEXACT = 0x8000000, -- flag: allow seeking to inexact position
	BASS_POS_DECODE = 0x10000000, -- flag: get the decoding (not playing) position
	BASS_POS_DECODETO = 0x20000000, -- flag: decode to the position instead of seeking
	BASS_POS_SCAN = 0x40000000, -- flag: scan to the position

	----------------------------------------------------------------------------
	-- BASS FX
	BASS_FX_FREESOURCE = 0x10000, -- Free the source handle as well?

	-- tempo attributes (BASS_ChannelSet/GetAttribute)
	BASS_ATTRIB_TEMPO = 0x10000,
	BASS_ATTRIB_TEMPO_PITCH = 0x10001,
	BASS_ATTRIB_TEMPO_FREQ = 0x10002,

	----------------------------------------------------------------------------
	-- BASS MIX

	-- BASS_Mixer_StreamCreate flags
	BASS_MIXER_RESUME = 0x1000, -- resume stalled immediately upon new/unpaused source
	BASS_MIXER_POSEX = 0x2000, -- enable BASS_Mixer_ChannelGetPositionEx support
	BASS_MIXER_NOSPEAKER = 0x4000, -- ignore speaker arrangement
	BASS_MIXER_QUEUE = 0x8000, -- queue sources
	BASS_MIXER_END = 0x10000, -- end the stream when there are no sources
	BASS_MIXER_NONSTOP = 0x20000, -- don't stall when there are no sources

	-- BASS_Mixer_StreamAddChannel/Ex flags
	BASS_MIXER_CHAN_ABSOLUTE = 0x1000, -- start is an absolute position
	BASS_MIXER_CHAN_BUFFER = 0x2000, -- buffer data for BASS_Mixer_ChannelGetData/Level
	BASS_MIXER_CHAN_LIMIT = 0x4000, -- limit mixer processing to the amount available from this source
	BASS_MIXER_CHAN_MATRIX = 0x10000, -- matrix mixing
	BASS_MIXER_CHAN_PAUSE = 0x20000, -- don't process the source
	BASS_MIXER_CHAN_DOWNMIX = 0x400000, -- downmix to stereo/mono
	BASS_MIXER_CHAN_NORAMPIN = 0x800000, -- don't ramp-in the start
	BASS_MIXER_BUFFER = 0x2000,
	BASS_MIXER_LIMIT = 0x4000,
	BASS_MIXER_MATRIX = 0x10000,
	BASS_MIXER_PAUSE = 0x20000,
	BASS_MIXER_DOWNMIX = 0x400000,
	BASS_MIXER_NORAMPIN = 0x800000,

	-- Additional BASS_Mixer_ChannelIsActive return values
	BASS_ACTIVE_WAITING = 5,
	BASS_ACTIVE_QUEUED = 6,
}
