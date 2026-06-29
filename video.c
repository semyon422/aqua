/*
Linux:
gcc -I$TREE/include/luajit-2.1 -fPIC -shared -o video.so video.c -lavformat -lavcodec -lswscale -lavutil -lm

Windows:
open msys2 mingw64
pacman -S make mingw-w64-x86_64-gcc
clone lua-dev-env,
shell-mingw.bat
clone-luajit.bat
build-mingw.bat
https://github.com/BtbN/FFmpeg-Builds/releases
gcc -I%TREE%/include/luajit-2.1 -Iffmpeg/include -fPIC -shared -o video.dll video.c -L%TREE%/lib -Lffmpeg/lib -l:libluajit-5.1.dll.a -lavformat -lavcodec -lswscale -lavutil -lm
*/

#include <lua.h>
#include <lauxlib.h>
#include <errno.h>
#include <stdbool.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/imgutils.h>
#include <libavutil/mathematics.h>
#include <libavutil/pixdesc.h>
#include <libswscale/swscale.h>
#include <libavutil/log.h>

#define MT_NAME "video"
#define FILE_BUFFER_SIZE 8192

typedef struct {
	AVFormatContext *formatContext;
	AVIOContext* ioContext;
	const AVCodec *codec;
	AVCodecContext *codecContext;
	int streamIndex;
	AVStream *stream;
	AVFrame *frame;
	AVFrame *frameRGB;
	struct SwsContext *swsContext;
	uint8_t *image;
	int imageSize;
	uint8_t *fileBuffer;
	bool isOpened;
	uint8_t *fileContent;
	int64_t fileSize;
	int64_t fileOffset;
	bool hasPendingFrame;
	lua_Number pendingFrameTime;
} Video;

static Video *checkVideo(lua_State *L, int i, bool open) {
	Video *video = (Video *)luaL_checkudata(L, i, MT_NAME);
	if (open) luaL_argcheck(L, video->isOpened, i, "attempt to use a closed video");
	return video;
}

int fileRead(void *ptr, uint8_t *buf, int len) {
	Video *video = (Video *)ptr;

	if (video->fileOffset >= video->fileSize)
		return AVERROR_EOF;

	int64_t remaining = video->fileSize - video->fileOffset;
	if (remaining < len)
		len = remaining;

	memcpy(buf, video->fileContent + video->fileOffset, len);
	video->fileOffset += len;

	return len;
}

int64_t fileSeek(void *ptr, int64_t pos, int whence) {
	Video *video = (Video *)ptr;

	if (whence == AVSEEK_SIZE)
		return video->fileSize;

	switch (whence & ~AVSEEK_FORCE) {
	case SEEK_SET:
		break;
	case SEEK_CUR:
		pos += video->fileOffset;
		break;
	case SEEK_END:
		pos += video->fileSize;
		break;
	default:
		return AVERROR(EINVAL);
	}

	if (pos < 0)
		pos = 0;
	if (pos > video->fileSize)
		pos = video->fileSize;

	video->fileOffset = pos;
	return pos;
}

void _Video_close(Video *video) {
	if (video->formatContext) {
		video->formatContext->pb = NULL;
		avformat_close_input(&video->formatContext);
	}
	if (video->codecContext) avcodec_free_context(&video->codecContext);
	if (video->ioContext && video->ioContext->buffer) av_freep(&video->ioContext->buffer);
	if (video->ioContext) avio_context_free(&video->ioContext);
	if (video->frame) av_frame_free(&video->frame);
	if (video->frameRGB) av_frame_free(&video->frameRGB);
	if (video->swsContext) sws_freeContext(video->swsContext);
	if (video->image) av_freep(&video->image);

	video->isOpened = false;
}

static int Video_close(lua_State *L) {
	Video *video = checkVideo(L, 1, true);
	_Video_close(video);
	return 0;
}

int open_error(lua_State *L, const char *message) {
	Video *video = checkVideo(L, -1, true);
	_Video_close(video);
	lua_pushnil(L);
	lua_pushstring(L, message);
	return 2;
}

static bool scale_frame(
	struct SwsContext **swsContext,
	AVFrame *frame,
	AVFrame *frameRGB,
	int dst_width,
	int dst_height
) {
	int src_width = frame->width > 0 ? frame->width : dst_width;
	int src_height = frame->height > 0 ? frame->height : dst_height;
	enum AVPixelFormat src_format = frame->format >= 0 ? (enum AVPixelFormat)frame->format : AV_PIX_FMT_NONE;

	if (
		src_width <= 0 ||
		src_height <= 0 ||
		dst_width <= 0 ||
		dst_height <= 0 ||
		src_format == AV_PIX_FMT_NONE ||
		!av_pix_fmt_desc_get(src_format) ||
		!frame->data[0]
	) {
		return false;
	}

	*swsContext = sws_getCachedContext(
		*swsContext,
		src_width,
		src_height,
		src_format,
		dst_width,
		dst_height,
		AV_PIX_FMT_RGBA,
		2,
		NULL,
		NULL,
		NULL
	);
	if (!*swsContext) {
		return false;
	}

	return sws_scale(
		*swsContext,
		(const uint8_t *const *)(frame->data),
		frame->linesize,
		0,
		src_height,
		frameRGB->data,
		frameRGB->linesize
	) > 0;
}

static int tight_rgba_size(int width, int height) {
	return width * height * 4;
}

// sws_scale writes rows using FFmpeg's aligned linesize, which can include
// padding past the visible width. Lua/LÖVE callers expect tightly packed RGBA,
// so copy only the visible bytes from each row.
static void copy_rgba_frame(uint8_t *dst, AVFrame *frameRGBA, int width, int height) {
	int rowSize = width * 4;

	if (frameRGBA->linesize[0] == rowSize) {
		memcpy(dst, frameRGBA->data[0], tight_rgba_size(width, height));
		return;
	}

	for (int y = 0; y < height; y++) {
		memcpy(dst + y * rowSize, frameRGBA->data[0] + y * frameRGBA->linesize[0], rowSize);
	}
}

static void push_rgba_frame(lua_State *L, AVFrame *frameRGBA, int width, int height) {
	int rowSize = width * 4;

	if (frameRGBA->linesize[0] == rowSize) {
		lua_pushlstring(L, (const char *)frameRGBA->data[0], tight_rgba_size(width, height));
		return;
	}

	luaL_Buffer buffer;
	luaL_buffinit(L, &buffer);
	for (int y = 0; y < height; y++) {
		luaL_addlstring(&buffer, (const char *)frameRGBA->data[0] + y * frameRGBA->linesize[0], rowSize);
	}
	luaL_pushresult(&buffer);
}

static int Video_open(lua_State *L) {
	Video *video = (Video *)lua_newuserdata(L, sizeof(Video));
	luaL_getmetatable(L, MT_NAME);
	lua_setmetatable(L, -2);

	memset(video, 0, sizeof(Video));

	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	video->fileContent = lua_touserdata(L, 1);
	video->fileSize = luaL_checkinteger(L, 2);

	video->isOpened = true;

	video->fileBuffer = av_malloc(FILE_BUFFER_SIZE);
	if (!video->fileBuffer)
		return open_error(L, "Can't allocate file buffer");

	video->ioContext = avio_alloc_context(
		video->fileBuffer,
		FILE_BUFFER_SIZE,
		0,
		video,
		fileRead,
		NULL,
		fileSeek
	);
	if (!video->ioContext)
		return open_error(L, "Can't allocate AVIOContext");

	video->formatContext = avformat_alloc_context();
	if (!video->formatContext)
		return open_error(L, "Can't allocate AVFormatContext");

	video->formatContext->pb = video->ioContext;
	video->formatContext->flags |= AVFMT_FLAG_CUSTOM_IO;
	video->formatContext->probesize = 32768;
	video->formatContext->max_analyze_duration = AV_TIME_BASE / 4;

	if (avformat_open_input(&video->formatContext, "", NULL, NULL) != 0)
		return open_error(L, "Can't open input");

	if (avformat_find_stream_info(video->formatContext, NULL) != 0)
		return open_error(L, "Can't find stream info");

	video->streamIndex = av_find_best_stream(
		video->formatContext, AVMEDIA_TYPE_VIDEO, -1, -1, &video->codec, 0
	);
	if (video->streamIndex == AVERROR_STREAM_NOT_FOUND)
		return open_error(L, "Stream not found");
	if (video->streamIndex == AVERROR_DECODER_NOT_FOUND)
		return open_error(L, "Decoder not found");

	video->stream = video->formatContext->streams[video->streamIndex];

	video->codecContext = avcodec_alloc_context3(video->codec);
	if (!video->codecContext)
		return open_error(L, "Can't allocate AVCodecContext");

	if (avcodec_parameters_to_context(video->codecContext, video->stream->codecpar) < 0)
		return open_error(L, "Can't fill the codec context");

	if (avcodec_open2(video->codecContext, video->codec, NULL) != 0)
		return open_error(L, "Can't open codec");

	video->frame = av_frame_alloc();
	video->frameRGB = av_frame_alloc();
	if (!video->frame || !video->frameRGB)
		return open_error(L, "Can't allocate frames");

	AVCodecContext *cctx = video->codecContext;

	video->imageSize = tight_rgba_size(cctx->width, cctx->height);

	if (av_image_alloc(
		video->frameRGB->data,
		video->frameRGB->linesize,
		cctx->width,
		cctx->height,
		AV_PIX_FMT_RGBA,
		32
	) < 0)
		return open_error(L, "Can't allocate image buffer");
	video->image = video->frameRGB->data[0];

	video->swsContext = sws_getContext(
		cctx->width,
		cctx->height,
		cctx->pix_fmt,
		cctx->width,
		cctx->height,
		AV_PIX_FMT_RGBA,
		2,
		NULL,
		NULL,
		NULL
	);
	if (!video->swsContext)
		return open_error(L, "Can't allocate SwsContext");

	return 1;
}

static int Video_getDimensions(lua_State *L) {
	Video *video = checkVideo(L, 1, true);

	AVCodecContext *cctx = video->codecContext;
	lua_pushnumber(L, (lua_Number)cctx->width);
	lua_pushnumber(L, (lua_Number)cctx->height);

	return 2;
}

// https://ffmpeg.org/doxygen/trunk/structAVStream.html#a7c67ae70632c91df8b0f721658ec5377
int64_t stream_start_time(AVStream *stream) {
	int64_t start_time = stream->start_time;
	if (start_time == AV_NOPTS_VALUE) {
		return 0;
	}
	return start_time;
}

static lua_Number frame_time(Video *video) {
	int64_t effort = video->frame->best_effort_timestamp;
	AVRational base = video->stream->time_base;

	if (effort < 0) {
		return 0;
	}
	return (lua_Number)(effort - stream_start_time(video->stream)) * base.num / base.den;
}

static int Video_getDuration(lua_State *L) {
	Video *video = checkVideo(L, 1, true);

	AVRational base = video->stream->time_base;

	lua_Number duration = (lua_Number)(video->stream->duration) * base.num / base.den;
	lua_pushnumber(L, duration);

	return 1;
}

static int Video_tell(lua_State *L) {
	Video *video = checkVideo(L, 1, true);

	lua_pushnumber(L, frame_time(video));

	return 1;
}

static int64_t seconds_to_stream_ts(AVStream *stream, lua_Number time) {
	int64_t start_time = stream_start_time(stream);
	int64_t relative_ts = av_rescale_q(
		(int64_t)llround(time * AV_TIME_BASE),
		AV_TIME_BASE_Q,
		stream->time_base
	);
	return start_time + relative_ts;
}

static int Video_seek(lua_State *L) {
	Video *video = checkVideo(L, 1, true);
	lua_Number time = luaL_checknumber(L, 2);

	AVStream *stream = video->stream;
	int64_t ts = seconds_to_stream_ts(stream, time);

	int ret = av_seek_frame(
		video->formatContext,
		video->streamIndex,
		ts,
		AVSEEK_FLAG_BACKWARD
	);
	if (ret < 0) {
		av_seek_frame(
			video->formatContext,
			video->streamIndex,
			ts,
			AVSEEK_FLAG_BACKWARD | AVSEEK_FLAG_ANY
		);
	}
	avcodec_flush_buffers(video->codecContext);
	av_frame_unref(video->frame);
	video->hasPendingFrame = false;

	return 0;
}

static int receive_frame(Video *video, lua_Number *time) {
	while (true) {
		int ret = avcodec_receive_frame(video->codecContext, video->frame);
		if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
			return 0;
		}
		if (ret < 0) {
			return 0;
		}

		if (!scale_frame(
			&video->swsContext,
			video->frame,
			video->frameRGB,
			video->codecContext->width,
			video->codecContext->height
		)) {
			av_frame_unref(video->frame);
			continue;
		}

		*time = frame_time(video);
		av_frame_unref(video->frame);
		return 1;
	}
}

static int read_next_frame(Video *video, lua_Number *time) {
	if (receive_frame(video, time)) {
		return 1;
	}

	AVPacket *packet = av_packet_alloc();
	if (!packet) {
		return 0;
	}

	while (av_read_frame(video->formatContext, packet) >= 0) {
		if (packet->stream_index == video->streamIndex) {
			int ret = avcodec_send_packet(video->codecContext, packet);
			av_packet_unref(packet);
			if (ret < 0) {
				break;
			}
			if (receive_frame(video, time)) {
				av_packet_free(&packet);
				return 1;
			}
		} else {
			av_packet_unref(packet);
		}
	}

	avcodec_send_packet(video->codecContext, NULL);
	if (receive_frame(video, time)) {
		av_packet_free(&packet);
		return 1;
	}

	av_packet_free(&packet);
	return 0;
}

static void copy_current_frame(Video *video, void *dst) {
	copy_rgba_frame(
		dst,
		video->frameRGB,
		video->codecContext->width,
		video->codecContext->height
	);
}

static int Video_read(lua_State *L) {
	Video *video = checkVideo(L, 1, true);
	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	void *dst = lua_touserdata(L, 2);
	lua_Number time;

	if (video->hasPendingFrame) {
		copy_current_frame(video, dst);
		lua_pushnumber(L, video->pendingFrameTime);
		video->hasPendingFrame = false;
		return 1;
	}

	if (!read_next_frame(video, &time)) {
		return 0;
	}

	copy_current_frame(video, dst);
	lua_pushnumber(L, time);
	return 1;
}

static int Video_readAt(lua_State *L) {
	Video *video = checkVideo(L, 1, true);
	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	void *dst = lua_touserdata(L, 2);
	lua_Number targetTime = luaL_checknumber(L, 3);
	lua_Number selectedTime = 0;
	bool hasSelectedFrame = false;

	if (video->hasPendingFrame) {
		if (video->pendingFrameTime > targetTime) {
			return 0;
		}

		copy_current_frame(video, dst);
		selectedTime = video->pendingFrameTime;
		hasSelectedFrame = true;
		video->hasPendingFrame = false;
	}

	lua_Number time;
	while (read_next_frame(video, &time)) {
		if (time > targetTime) {
			video->hasPendingFrame = true;
			video->pendingFrameTime = time;
			break;
		}

		copy_current_frame(video, dst);
		selectedTime = time;
		hasSelectedFrame = true;
	}

	if (!hasSelectedFrame) {
		return 0;
	}

	lua_pushnumber(L, selectedTime);
	return 1;
}

static int Video_tostring(lua_State *L) {
	Video *video = checkVideo(L, 1, false);
	lua_pushfstring(L, "video (%p)", video);
	return 1;
}

static int Video_gc(lua_State *L) {
	Video *video = checkVideo(L, 1, false);
	if (video->isOpened) {
		Video_close(L);
	}
	return 0;
}

static const struct luaL_Reg video_reg_mt[] = {
	{"__tostring", Video_tostring},
	{"__gc", Video_gc},
	{"open", Video_open},
	{"close", Video_close},
	{"tell", Video_tell},
	{"read", Video_read},
	{"readAt", Video_readAt},
	{"seek", Video_seek},
	{"getDuration", Video_getDuration},
	{"getDimensions", Video_getDimensions},
	{NULL, NULL}
};

typedef struct {
	uint8_t *content;
	int64_t size;
	int64_t offset;
} MemoryInput;

static int memoryRead(void *ptr, uint8_t *buf, int len) {
	MemoryInput *input = (MemoryInput *)ptr;

	if (input->offset >= input->size)
		return AVERROR_EOF;

	int64_t remaining = input->size - input->offset;
	if (remaining < len)
		len = remaining;

	memcpy(buf, input->content + input->offset, len);
	input->offset += len;

	return len;
}

static int64_t memorySeek(void *ptr, int64_t pos, int whence) {
	MemoryInput *input = (MemoryInput *)ptr;

	if (whence == AVSEEK_SIZE)
		return input->size;

	switch (whence & ~AVSEEK_FORCE) {
	case SEEK_SET:
		break;
	case SEEK_CUR:
		pos += input->offset;
		break;
	case SEEK_END:
		pos += input->size;
		break;
	default:
		return AVERROR(EINVAL);
	}

	if (pos < 0)
		pos = 0;
	if (pos > input->size)
		pos = input->size;

	input->offset = pos;

	return pos;
}

static int image_decode_error(lua_State *L, const char *message) {
	lua_pushnil(L);
	lua_pushstring(L, message);
	return 2;
}

static int Video_decodeImage(lua_State *L) {
	MemoryInput input;
	if (lua_type(L, 1) == LUA_TSTRING) {
		size_t size = 0;
		input.content = (uint8_t *)lua_tolstring(L, 1, &size);
		input.size = size;
	} else {
		luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
		input.content = lua_touserdata(L, 1);
		input.size = luaL_checkinteger(L, 2);
	}
	input.offset = 0;

	AVFormatContext *formatContext = NULL;
	AVIOContext *ioContext = NULL;
	AVCodecContext *codecContext = NULL;
	const AVCodec *codec = NULL;
	AVFrame *frame = NULL;
	AVFrame *frameRGBA = NULL;
	AVPacket *packet = NULL;
	struct SwsContext *swsContext = NULL;
	uint8_t *fileBuffer = NULL;
	uint8_t *image = NULL;
	int imageSize = 0;
	int streamIndex = -1;
	int ret = 0;
	int result = 0;

	fileBuffer = av_malloc(FILE_BUFFER_SIZE);
	if (!fileBuffer) {
		result = image_decode_error(L, "Can't allocate file buffer");
		goto cleanup;
	}

	ioContext = avio_alloc_context(fileBuffer, FILE_BUFFER_SIZE, 0, &input, memoryRead, NULL, memorySeek);
	if (!ioContext) {
		result = image_decode_error(L, "Can't allocate AVIOContext");
		goto cleanup;
	}
	fileBuffer = NULL;

	formatContext = avformat_alloc_context();
	if (!formatContext) {
		result = image_decode_error(L, "Can't allocate AVFormatContext");
		goto cleanup;
	}
	formatContext->pb = ioContext;
	formatContext->flags |= AVFMT_FLAG_CUSTOM_IO;

	if (avformat_open_input(&formatContext, "", NULL, NULL) != 0) {
		result = image_decode_error(L, "Can't open input");
		goto cleanup;
	}
	if (avformat_find_stream_info(formatContext, NULL) != 0) {
		result = image_decode_error(L, "Can't find stream info");
		goto cleanup;
	}

	streamIndex = av_find_best_stream(formatContext, AVMEDIA_TYPE_VIDEO, -1, -1, &codec, 0);
	if (streamIndex == AVERROR_STREAM_NOT_FOUND) {
		result = image_decode_error(L, "Image stream not found");
		goto cleanup;
	}
	if (streamIndex == AVERROR_DECODER_NOT_FOUND) {
		result = image_decode_error(L, "Image decoder not found");
		goto cleanup;
	}

	codecContext = avcodec_alloc_context3(codec);
	if (!codecContext) {
		result = image_decode_error(L, "Can't allocate AVCodecContext");
		goto cleanup;
	}
	if (avcodec_parameters_to_context(codecContext, formatContext->streams[streamIndex]->codecpar) < 0) {
		result = image_decode_error(L, "Can't fill codec context");
		goto cleanup;
	}
	if (avcodec_open2(codecContext, codec, NULL) != 0) {
		result = image_decode_error(L, "Can't open image codec");
		goto cleanup;
	}

	frame = av_frame_alloc();
	frameRGBA = av_frame_alloc();
	packet = av_packet_alloc();
	if (!frame || !frameRGBA || !packet) {
		result = image_decode_error(L, "Can't allocate image frame");
		goto cleanup;
	}

	imageSize = av_image_alloc(
		frameRGBA->data,
		frameRGBA->linesize,
		codecContext->width,
		codecContext->height,
		AV_PIX_FMT_RGBA,
		32
	);
	if (imageSize < 0) {
		result = image_decode_error(L, "Can't allocate image buffer");
		goto cleanup;
	}
	image = frameRGBA->data[0];

	while ((ret = av_read_frame(formatContext, packet)) >= 0) {
		if (packet->stream_index == streamIndex) {
			ret = avcodec_send_packet(codecContext, packet);
			av_packet_unref(packet);
			if (ret < 0)
				break;

			ret = avcodec_receive_frame(codecContext, frame);
			if (ret == 0) {
				if (!scale_frame(
					&swsContext,
					frame,
					frameRGBA,
					codecContext->width,
					codecContext->height
				)) {
					av_frame_unref(frame);
					continue;
				}

				push_rgba_frame(L, frameRGBA, codecContext->width, codecContext->height);
				lua_pushinteger(L, codecContext->width);
				lua_pushinteger(L, codecContext->height);
				result = 3;
				goto cleanup;
			}
			if (ret != AVERROR(EAGAIN) && ret != AVERROR_EOF)
				break;
		} else {
			av_packet_unref(packet);
		}
	}

	avcodec_send_packet(codecContext, NULL);
	if (avcodec_receive_frame(codecContext, frame) == 0) {
		if (scale_frame(
			&swsContext,
			frame,
			frameRGBA,
			codecContext->width,
			codecContext->height
		)) {
			push_rgba_frame(L, frameRGBA, codecContext->width, codecContext->height);
			lua_pushinteger(L, codecContext->width);
			lua_pushinteger(L, codecContext->height);
			result = 3;
			goto cleanup;
		}
	}

	result = image_decode_error(L, "Can't decode image frame");

cleanup:
	if (image) av_freep(&image);
	if (swsContext) sws_freeContext(swsContext);
	if (packet) av_packet_free(&packet);
	if (frameRGBA) av_frame_free(&frameRGBA);
	if (frame) av_frame_free(&frame);
	if (codecContext) avcodec_free_context(&codecContext);
	if (formatContext) {
		formatContext->pb = NULL;
		avformat_close_input(&formatContext);
	}
	if (ioContext && ioContext->buffer) av_freep(&ioContext->buffer);
	if (ioContext) avio_context_free(&ioContext);
	if (fileBuffer) av_free(fileBuffer);

	return result;
}

static const struct luaL_Reg video_reg[] = {
	{"open", Video_open},
	{"decode_image", Video_decodeImage},
	{NULL, NULL}
};

int LUA_API luaopen_video(lua_State *L) {
	av_log_set_level(AV_LOG_QUIET);

	luaL_newmetatable(L, MT_NAME);
	lua_pushstring(L, "__index");
	lua_pushvalue(L, -2);
	lua_settable(L, -3);
	luaL_openlib(L, NULL, video_reg_mt, 0);

	lua_newtable(L);
	luaL_setfuncs(L, video_reg, 0);

	return 1;
}
