#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/log.h>
#include <libavutil/opt.h>
#include <libavutil/samplefmt.h>
#include <libswresample/swresample.h>

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#define WINAPI __stdcall
#define CALLBACK __stdcall
#define BASS_EXPORT __declspec(dllexport)
#else
#define WINAPI
#define CALLBACK
#define BASS_EXPORT __attribute__((visibility("default")))
#endif

typedef uint8_t BYTE;
typedef uint32_t DWORD;
typedef uint64_t QWORD;
typedef int BOOL;
typedef DWORD HSTREAM;
typedef DWORD HPLUGIN;
typedef DWORD HSAMPLE;
typedef DWORD HSYNC;
typedef DWORD HFX;
typedef void *BASSFILE;

#define TRUE 1
#define FALSE 0

#define BASSVERSION 0x204
#define BASS_OK 0
#define BASS_ERROR_MEM 1
#define BASS_ERROR_FILEFORM 41
#define BASS_ERROR_NOTAVAIL 37
#define BASS_ERROR_POSITION 7
#define BASS_ERROR_ENDED 45

#define BASS_SAMPLE_FLOAT 0x100
#define BASS_STREAM_DECODE 0x200000
#define BASS_UNICODE 0x80000000
#define BASS_CTYPE_STREAM_FFMPEG 0x1f301
#define BASS_POS_BYTE 0
#define BASS_STREAMPROC_END 0x80000000
#define BASS_FILEPOS_CURRENT 0
#define BASS_FILEPOS_END 2
#define BASS_FILEPOS_SIZE 8

#define BASSPLUGIN_INFO 0
#define BASSPLUGIN_CREATE 1
#define BASS_CONFIG_ADDON 0x8000

#define BASSFILE_EX_TAGS 1

typedef DWORD(CALLBACK STREAMPROC)(HSTREAM handle, void *buffer, DWORD length, void *user);

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

typedef struct {
	DWORD flags;
	void(WINAPI *Free)(void *inst);
	QWORD(WINAPI *GetLength)(void *inst, DWORD mode);
	const char *(WINAPI *GetTags)(void *inst, DWORD tags);
	QWORD(WINAPI *GetFilePosition)(void *inst, DWORD mode);
	void(WINAPI *GetInfo)(void *inst, BASS_CHANNELINFO *info);
	BOOL(WINAPI *CanSetPosition)(void *inst, QWORD pos, DWORD mode);
	QWORD(WINAPI *SetPosition)(void *inst, QWORD pos, DWORD mode);
	QWORD(WINAPI *GetPosition)(void *inst, QWORD pos, DWORD mode);
	HSYNC(WINAPI *SetSync)(void *inst, DWORD type, QWORD param, void *proc, void *user);
	void(WINAPI *RemoveSync)(void *inst, HSYNC sync);
	BOOL(WINAPI *CanResume)(void *inst);
	DWORD(WINAPI *SetFlags)(void *inst, DWORD flags);
	BOOL(WINAPI *Attribute)(void *inst, DWORD attrib, float *value, BOOL set);
	DWORD(WINAPI *AttributeEx)(void *inst, DWORD attrib, void *value, DWORD typesize, BOOL set);
} ADDON_FUNCTIONS;

typedef struct {
	void(WINAPI *SetError)(int error);
	void(WINAPI *RegisterPlugin)(void *proc, DWORD mode);
	HSTREAM(WINAPI *CreateStream)(DWORD freq, DWORD chans, DWORD flags, STREAMPROC *proc, void *inst, const ADDON_FUNCTIONS *funcs);
	HFX(WINAPI *SetFX)(DWORD handle, void *proc, void *inst, int priority, void *funcs);
	void *(WINAPI *GetInst)(HSTREAM handle, const ADDON_FUNCTIONS *funcs);
	void *reserved1;
	HSYNC(WINAPI *NewSync)(HSTREAM handle, DWORD type, void *proc, void *user);
	BOOL(WINAPI *TriggerSync)(HSTREAM handle, DWORD type, QWORD pos, DWORD data);
	QWORD(WINAPI *GetCount)(DWORD handle, BOOL output);
	QWORD(WINAPI *GetPosition)(DWORD handle, QWORD count, DWORD mode);

	struct {
		BASSFILE(WINAPI *Open)(DWORD filetype, const void *file, QWORD offset, QWORD length, DWORD flags, DWORD exflags);
		BASSFILE(WINAPI *OpenURL)(const char *url, DWORD offset, DWORD flags, void *proc, void *user, DWORD exflags);
		BASSFILE(WINAPI *OpenUser)(DWORD system, DWORD flags, const void *proc, void *user, DWORD exflags);
		void(WINAPI *Close)(BASSFILE file);
		const char *(WINAPI *GetFileName)(BASSFILE file, BOOL *unicode);
		BOOL(WINAPI *SetStream)(BASSFILE file, HSTREAM handle);
		DWORD(WINAPI *GetFlags)(BASSFILE file);
		void(WINAPI *SetFlags)(BASSFILE file, DWORD flags);
		DWORD(WINAPI *Read)(BASSFILE file, void *buf, DWORD len);
		BOOL(WINAPI *Seek)(BASSFILE file, QWORD pos);
		QWORD(WINAPI *GetPos)(BASSFILE file, DWORD mode);
		BOOL(WINAPI *Eof)(BASSFILE file);
		const char *(WINAPI *GetTags)(BASSFILE file, DWORD tags);
		BOOL(WINAPI *StartThread)(BASSFILE file, DWORD bytespersec, DWORD offset);
		BOOL(WINAPI *CanResume)(BASSFILE file);
	} file;
} BASS_FUNCTIONS;

extern const void *WINAPI BASS_GetConfigPtr(DWORD option);

static const BASS_FUNCTIONS *bassfunc;

typedef struct {
	BASSFILE file;
	unsigned char *avio_buffer;
	AVIOContext *avio;
	AVFormatContext *format;
	AVCodecContext *codec;
	const AVCodec *decoder;
	SwrContext *swr;
	AVPacket *packet;
	AVFrame *frame;
	int stream_index;
	int sample_rate;
	int channels;
	enum AVSampleFormat out_format;
	DWORD flags;
	QWORD length;
	QWORD position;
	uint8_t *buffer;
	int buffer_size;
	int buffer_pos;
	int buffer_len;
	BOOL decoder_flushed;
	BOOL eof;
} FFmpegBassStream;

static const BASS_PLUGINFORM plugin_forms[] = {
	{BASS_CTYPE_STREAM_FFMPEG, "FFmpeg", "*.*"}
};
static const BASS_PLUGININFO plugin_info = {BASSVERSION, 1, plugin_forms};

static BOOL reset_decode(FFmpegBassStream *stream);

static DWORD bytes_per_sample(const FFmpegBassStream *stream) {
	return stream->out_format == AV_SAMPLE_FMT_FLT ? 4 : 2;
}

static int io_read(void *opaque, uint8_t *buffer, int length) {
	FFmpegBassStream *stream = (FFmpegBassStream *)opaque;
	DWORD read = bassfunc->file.Read(stream->file, buffer, (DWORD)length);
	return read ? (int)read : AVERROR_EOF;
}

static int64_t io_seek(void *opaque, int64_t offset, int whence) {
	FFmpegBassStream *stream = (FFmpegBassStream *)opaque;
	if (whence == AVSEEK_SIZE) {
		return (int64_t)bassfunc->file.GetPos(stream->file, BASS_FILEPOS_SIZE);
	}
	if (whence == SEEK_CUR) {
		offset += (int64_t)bassfunc->file.GetPos(stream->file, BASS_FILEPOS_CURRENT);
	} else if (whence == SEEK_END) {
		offset += (int64_t)bassfunc->file.GetPos(stream->file, BASS_FILEPOS_END);
	} else if (whence != SEEK_SET) {
		return AVERROR(EINVAL);
	}
	if (offset < 0 || !bassfunc->file.Seek(stream->file, (QWORD)offset)) {
		return AVERROR(EIO);
	}
	return offset;
}

static QWORD stream_length(FFmpegBassStream *stream) {
	double seconds = 0;
	AVStream *av_stream = stream->format->streams[stream->stream_index];
	if (av_stream->duration != AV_NOPTS_VALUE) {
		seconds = av_stream->duration * av_q2d(av_stream->time_base);
	} else if (stream->format->duration != AV_NOPTS_VALUE) {
		seconds = (double)stream->format->duration / AV_TIME_BASE;
	}
	if (seconds <= 0) {
		return 0;
	}
	return (QWORD)(seconds * stream->sample_rate * stream->channels * bytes_per_sample(stream));
}

static BOOL ensure_buffer(FFmpegBassStream *stream, int samples) {
	int bytes = samples * stream->channels * (int)bytes_per_sample(stream);
	if (bytes <= stream->buffer_size) {
		return TRUE;
	}
	uint8_t *buffer = (uint8_t *)realloc(stream->buffer, (size_t)bytes);
	if (!buffer) {
		return FALSE;
	}
	stream->buffer = buffer;
	stream->buffer_size = bytes;
	return TRUE;
}

static BOOL push_frame(FFmpegBassStream *stream) {
	int out_samples = swr_get_out_samples(stream->swr, stream->frame->nb_samples);
	if (out_samples < 0 || !ensure_buffer(stream, out_samples)) {
		return FALSE;
	}
	uint8_t *out[] = {stream->buffer};
	int samples = swr_convert(
		stream->swr,
		out,
		out_samples,
		(const uint8_t *const *)stream->frame->extended_data,
		stream->frame->nb_samples
	);
	if (samples < 0) {
		return FALSE;
	}
	stream->buffer_pos = 0;
	stream->buffer_len = samples * stream->channels * (int)bytes_per_sample(stream);
	return TRUE;
}

static BOOL flush_swr(FFmpegBassStream *stream) {
	int delay = (int)swr_get_delay(stream->swr, stream->codec->sample_rate);
	if (delay <= 0 || !ensure_buffer(stream, delay)) {
		return FALSE;
	}
	uint8_t *out[] = {stream->buffer};
	int samples = swr_convert(stream->swr, out, delay, NULL, 0);
	if (samples <= 0) {
		return FALSE;
	}
	stream->buffer_pos = 0;
	stream->buffer_len = samples * stream->channels * (int)bytes_per_sample(stream);
	return TRUE;
}

static BOOL fill_buffer(FFmpegBassStream *stream) {
	int result;
	if (stream->buffer_pos < stream->buffer_len) {
		return TRUE;
	}
	stream->buffer_pos = 0;
	stream->buffer_len = 0;
	if (stream->eof) {
		return FALSE;
	}

	for (;;) {
		result = avcodec_receive_frame(stream->codec, stream->frame);
		if (result == 0) {
			BOOL ok = push_frame(stream);
			av_frame_unref(stream->frame);
			if (!ok) {
				stream->eof = TRUE;
				return FALSE;
			}
			if (stream->buffer_len > 0) {
				return TRUE;
			}
			continue;
		}
		if (result == AVERROR_EOF) {
			if (flush_swr(stream)) {
				return TRUE;
			}
			stream->eof = TRUE;
			return FALSE;
		}
		if (result != AVERROR(EAGAIN)) {
			stream->eof = TRUE;
			return FALSE;
		}

		if (stream->decoder_flushed) {
			stream->eof = TRUE;
			return FALSE;
		}

		for (;;) {
			result = av_read_frame(stream->format, stream->packet);
			if (result == AVERROR_EOF) {
				avcodec_send_packet(stream->codec, NULL);
				stream->decoder_flushed = TRUE;
				break;
			}
			if (result < 0) {
				stream->eof = TRUE;
				return FALSE;
			}
			if (stream->packet->stream_index == stream->stream_index) {
				result = avcodec_send_packet(stream->codec, stream->packet);
				av_packet_unref(stream->packet);
				if (result == 0 || result == AVERROR(EAGAIN)) {
					break;
				}
				if (result != AVERROR_INVALIDDATA) {
					stream->eof = TRUE;
					return FALSE;
				}
			} else {
				av_packet_unref(stream->packet);
			}
		}
	}
}

static void free_stream(FFmpegBassStream *stream) {
	if (!stream) {
		return;
	}
	free(stream->buffer);
	av_frame_free(&stream->frame);
	av_packet_free(&stream->packet);
	swr_free(&stream->swr);
	avcodec_free_context(&stream->codec);
	avformat_close_input(&stream->format);
	if (stream->avio) {
		av_freep(&stream->avio->buffer);
		avio_context_free(&stream->avio);
	} else {
		av_free(stream->avio_buffer);
	}
	free(stream);
}

static BOOL reset_decode(FFmpegBassStream *stream) {
	stream->buffer_pos = 0;
	stream->buffer_len = 0;
	stream->decoder_flushed = FALSE;
	stream->eof = FALSE;
	avcodec_flush_buffers(stream->codec);
	swr_close(stream->swr);
	return swr_init(stream->swr) >= 0;
}

static BOOL open_stream(BASSFILE file, DWORD flags, FFmpegBassStream **out_stream) {
	FFmpegBassStream *stream = (FFmpegBassStream *)calloc(1, sizeof(*stream));
	if (!stream) {
		return FALSE;
	}
	stream->file = file;
	stream->flags = flags;
	stream->out_format = (flags & BASS_SAMPLE_FLOAT) ? AV_SAMPLE_FMT_FLT : AV_SAMPLE_FMT_S16;
	stream->stream_index = -1;
	stream->avio_buffer = (unsigned char *)av_malloc(32768);
	stream->avio = avio_alloc_context(stream->avio_buffer, 32768, 0, stream, io_read, NULL, io_seek);
	stream->format = avformat_alloc_context();
	stream->packet = av_packet_alloc();
	stream->frame = av_frame_alloc();
	if (!stream->avio_buffer || !stream->avio || !stream->format || !stream->packet || !stream->frame) {
		free_stream(stream);
		return FALSE;
	}
	stream->avio_buffer = NULL;
	stream->format->pb = stream->avio;
	stream->format->flags |= AVFMT_FLAG_CUSTOM_IO;
	if (avformat_open_input(&stream->format, NULL, NULL, NULL) < 0) {
		free_stream(stream);
		return FALSE;
	}
	if (avformat_find_stream_info(stream->format, NULL) < 0) {
		free_stream(stream);
		return FALSE;
	}
	stream->stream_index = av_find_best_stream(stream->format, AVMEDIA_TYPE_AUDIO, -1, -1, &stream->decoder, 0);
	if (stream->stream_index < 0 || !stream->decoder) {
		free_stream(stream);
		return FALSE;
	}
	stream->codec = avcodec_alloc_context3(stream->decoder);
	if (!stream->codec) {
		free_stream(stream);
		return FALSE;
	}
	if (avcodec_parameters_to_context(stream->codec, stream->format->streams[stream->stream_index]->codecpar) < 0) {
		free_stream(stream);
		return FALSE;
	}
	if (avcodec_open2(stream->codec, stream->decoder, NULL) < 0) {
		free_stream(stream);
		return FALSE;
	}
	stream->sample_rate = stream->codec->sample_rate;
	stream->channels = stream->codec->ch_layout.nb_channels;
	if (stream->sample_rate <= 0 || stream->channels <= 0) {
		free_stream(stream);
		return FALSE;
	}

	AVChannelLayout out_layout;
	av_channel_layout_default(&out_layout, stream->channels);
	stream->swr = swr_alloc();
	if (!stream->swr) {
		free_stream(stream);
		return FALSE;
	}
	av_opt_set_chlayout(stream->swr, "in_chlayout", &stream->codec->ch_layout, 0);
	av_opt_set_chlayout(stream->swr, "out_chlayout", &out_layout, 0);
	av_opt_set_int(stream->swr, "in_sample_rate", stream->codec->sample_rate, 0);
	av_opt_set_int(stream->swr, "out_sample_rate", stream->sample_rate, 0);
	av_opt_set_sample_fmt(stream->swr, "in_sample_fmt", stream->codec->sample_fmt, 0);
	av_opt_set_sample_fmt(stream->swr, "out_sample_fmt", stream->out_format, 0);
	av_channel_layout_uninit(&out_layout);
	if (swr_init(stream->swr) < 0) {
		free_stream(stream);
		return FALSE;
	}
	stream->length = stream_length(stream);
	*out_stream = stream;
	return TRUE;
}

static HSTREAM CALLBACK create_stream(BASSFILE file, DWORD flags);
static DWORD CALLBACK stream_proc(HSTREAM handle, void *buffer, DWORD length, void *user);
static void WINAPI addon_free(void *inst);
static QWORD WINAPI addon_get_length(void *inst, DWORD mode);
static void WINAPI addon_get_info(void *inst, BASS_CHANNELINFO *info);
static BOOL WINAPI addon_can_set_position(void *inst, QWORD position, DWORD mode);
static QWORD WINAPI addon_set_position(void *inst, QWORD position, DWORD mode);

static const ADDON_FUNCTIONS addon_functions = {
	0,
	addon_free,
	addon_get_length,
	NULL,
	NULL,
	addon_get_info,
	addon_can_set_position,
	addon_set_position,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
};

BASS_EXPORT const void *WINAPI BASSplugin(DWORD face) {
	av_log_set_level(AV_LOG_ERROR);
	if (!bassfunc) {
		bassfunc = (const BASS_FUNCTIONS *)BASS_GetConfigPtr(BASS_CONFIG_ADDON);
	}
	if (!bassfunc) {
		return NULL;
	}
	if (face == BASSPLUGIN_INFO) {
		return &plugin_info;
	}
	if (face == BASSPLUGIN_CREATE) {
		return create_stream;
	}
	return NULL;
}

static HSTREAM CALLBACK create_stream(BASSFILE file, DWORD flags) {
	FFmpegBassStream *stream = NULL;
	HSTREAM handle;
	if (!open_stream(file, flags, &stream)) {
		bassfunc->SetError(BASS_ERROR_FILEFORM);
		return 0;
	}
	handle = bassfunc->CreateStream((DWORD)stream->sample_rate, (DWORD)stream->channels, flags, stream_proc, stream, &addon_functions);
	if (!handle) {
		free_stream(stream);
		return 0;
	}
	bassfunc->file.SetStream(file, handle);
	bassfunc->SetError(BASS_OK);
	return handle;
}

BASS_EXPORT HSTREAM WINAPI BASS_FFMPEG_StreamCreateFile(DWORD filetype, const void *file, QWORD offset, QWORD length, DWORD flags) {
	BASSFILE bass_file;
	HSTREAM handle;
	if (!bassfunc) {
		bassfunc = (const BASS_FUNCTIONS *)BASS_GetConfigPtr(BASS_CONFIG_ADDON);
	}
	if (!bassfunc) {
		return 0;
	}
	bass_file = bassfunc->file.Open(filetype, file, offset, length, flags, BASSFILE_EX_TAGS);
	if (!bass_file) {
		return 0;
	}
	handle = create_stream(bass_file, flags);
	if (!handle) {
		bassfunc->file.Close(bass_file);
	}
	return handle;
}

static DWORD CALLBACK stream_proc(HSTREAM handle, void *buffer, DWORD length, void *user) {
	FFmpegBassStream *stream = (FFmpegBassStream *)user;
	DWORD written = 0;
	(void)handle;
	while (written < length) {
		DWORD available;
		DWORD copy;
		if (!fill_buffer(stream)) {
			if (stream->length > 0 && stream->position < stream->length) {
				QWORD remaining = stream->length - stream->position;
				copy = length - written;
				if ((QWORD)copy > remaining) {
					copy = (DWORD)remaining;
				}
				memset((uint8_t *)buffer + written, 0, copy);
				stream->position += copy;
				written += copy;
				continue;
			}
			return written ? written : BASS_STREAMPROC_END;
		}
		available = (DWORD)(stream->buffer_len - stream->buffer_pos);
		copy = length - written;
		if (copy > available) {
			copy = available;
		}
		memcpy((uint8_t *)buffer + written, stream->buffer + stream->buffer_pos, copy);
		stream->buffer_pos += (int)copy;
		stream->position += copy;
		written += copy;
	}
	return written;
}

static BOOL discard_to_position(FFmpegBassStream *stream, QWORD position) {
	uint8_t tmp[16384];
	QWORD discarded = 0;
	while (discarded < position) {
		QWORD need = position - discarded;
		DWORD chunk = need > sizeof(tmp) ? (DWORD)sizeof(tmp) : (DWORD)need;
		DWORD read = stream_proc(0, tmp, chunk, stream);
		if (read == BASS_STREAMPROC_END || read == 0) {
			return FALSE;
		}
		discarded += read;
	}
	stream->position = position;
	return TRUE;
}

static void WINAPI addon_free(void *inst) {
	free_stream((FFmpegBassStream *)inst);
}

static QWORD WINAPI addon_get_length(void *inst, DWORD mode) {
	FFmpegBassStream *stream = (FFmpegBassStream *)inst;
	if (mode == BASS_POS_BYTE && stream->length > 0) {
		bassfunc->SetError(BASS_OK);
		return stream->length;
	}
	bassfunc->SetError(BASS_ERROR_NOTAVAIL);
	return (QWORD)-1;
}

static void WINAPI addon_get_info(void *inst, BASS_CHANNELINFO *info) {
	FFmpegBassStream *stream = (FFmpegBassStream *)inst;
	info->ctype = BASS_CTYPE_STREAM_FFMPEG;
	info->origres = stream->out_format == AV_SAMPLE_FMT_FLT ? 32 : 16;
}

static BOOL WINAPI addon_can_set_position(void *inst, QWORD position, DWORD mode) {
	FFmpegBassStream *stream = (FFmpegBassStream *)inst;
	if (mode == BASS_POS_BYTE && stream->length > 0 && position <= stream->length) {
		bassfunc->SetError(BASS_OK);
		return TRUE;
	}
	bassfunc->SetError(BASS_ERROR_POSITION);
	return FALSE;
}

static QWORD WINAPI addon_set_position(void *inst, QWORD position, DWORD mode) {
	FFmpegBassStream *stream = (FFmpegBassStream *)inst;
	if (!addon_can_set_position(inst, position, mode)) {
		return (QWORD)-1;
	}
	if (av_seek_frame(stream->format, stream->stream_index, 0, AVSEEK_FLAG_BACKWARD) < 0 || !reset_decode(stream)) {
		bassfunc->SetError(BASS_ERROR_POSITION);
		return (QWORD)-1;
	}
	stream->position = 0;
	if (!discard_to_position(stream, position)) {
		bassfunc->SetError(BASS_ERROR_POSITION);
		return (QWORD)-1;
	}
	bassfunc->SetError(BASS_OK);
	return position;
}
