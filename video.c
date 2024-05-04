/*
Linux:
gcc -I$TREE/include/luajit-2.1 -fPIC -shared -o video.so video.c -lavformat -lavcodec -lswresample -lswscale -lavutil -lm

Windows:
msys2
mingw-w64-x86_64-make
mingw-w64-x86_64-gcc
compile luajit with mingw
https://github.com/BtbN/FFmpeg-Builds/releases
gcc -I%TREE%/include/luajit-2.1 -Iffmpeg/include -fPIC -shared -o video.dll video.c -L%TREE%/lib -Lffmpeg/lib -l:libluajit-5.1.dll.a -lavformat -lavcodec -lswresample -lswscale -lavutil -lm
*/

#include <lua.h>
#include <lauxlib.h>
#include <stdbool.h>
#include <math.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/imgutils.h>
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
} Video;

static Video *checkVideo(lua_State *L, int i, bool open) {
	Video *video = (Video *)luaL_checkudata(L, i, MT_NAME);
	if (open) luaL_argcheck(L, video->isOpened, i, "attempt to use a closed video");
	return video;
}

int fileRead(void *ptr, uint8_t *buf, int len) {
	Video *video = (Video *)ptr;

	if (video->fileOffset + len > video->fileSize)
		len = video->fileSize - video->fileOffset;
	if (len == 0)
		return AVERROR_EOF;

	memcpy(buf, video->fileContent + video->fileOffset, len);
	video->fileOffset += len;

	return len;
}

int64_t fileSeek(void *ptr, int64_t pos, int whence) {
	Video *video = (Video *)ptr;

	if (whence == AVSEEK_SIZE)
		return video->fileSize;

	video->fileOffset = pos;

	return pos;
}

void _Video_close(Video *video) {
	if (video->formatContext) avformat_close_input(&video->formatContext);
	if (video->codecContext) avcodec_close(video->codecContext);
	if (video->ioContext && video->ioContext->buffer) av_free(video->ioContext->buffer);
	if (video->ioContext) avio_context_free(&video->ioContext);
	if (video->frame) av_free(video->frame);
	if (video->frameRGB) av_free(video->frameRGB);
	if (video->swsContext) sws_freeContext(video->swsContext);
	if (video->image) free(video->image);

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

	video->imageSize = av_image_fill_arrays(
		video->frameRGB->data,
		video->frameRGB->linesize,
		NULL,
		AV_PIX_FMT_RGBA,
		cctx->width,
		cctx->height,
		1
	);
	if (video->imageSize < 0)
		return open_error(L, "Can't determine image buffer size");

	video->image = malloc(video->imageSize);
	if (!video->image)
		return open_error(L, "Can't allocate image buffer");

	if (av_image_fill_arrays(
		video->frameRGB->data,
		video->frameRGB->linesize,
		video->image,
		AV_PIX_FMT_RGBA,
		cctx->width,
		cctx->height,
		1
	) < 0)
		return open_error(L, "Can't setup the data pointers");

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

static int Video_tell(lua_State *L) {
	Video *video = checkVideo(L, 1, true);

	int64_t effort = video->frame->best_effort_timestamp;
	AVRational base = video->stream->time_base;

	if (effort < 0) {
		lua_pushinteger(L, 0);
		return 1;
	}
	lua_Number time = (lua_Number)(effort - stream_start_time(video->stream)) * base.num / base.den;
	lua_pushnumber(L, time);

	return 1;
}

static int Video_seek(lua_State *L) {
	Video *video = checkVideo(L, 1, true);
	lua_Number time = luaL_checknumber(L, 2);

	AVStream *stream = video->stream;
	AVRational base = stream->time_base;

	int64_t start_time = stream_start_time(stream);
	int64_t ts = time * base.den / base.num - start_time;
	int64_t cts = video->frame->best_effort_timestamp - start_time;

	int flags = AVSEEK_FLAG_ANY;
	if (cts > ts) {
		flags |= AVSEEK_FLAG_BACKWARD;
	}

	av_seek_frame(
		video->formatContext,
		video->streamIndex,
		ts,
		flags
	);
	avcodec_flush_buffers(video->codecContext);

	return 0;
}

AVPacket packet;
static int Video_read(lua_State *L) {
	Video *video = checkVideo(L, 1, true);
	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	void *dst = lua_touserdata(L, 2);

	while (!av_read_frame(video->formatContext, &packet)) {
		if (packet.stream_index == video->streamIndex) {
			avcodec_send_packet(video->codecContext, &packet);
			av_packet_unref(&packet);

			if (!avcodec_receive_frame(video->codecContext, video->frame)) {
				sws_scale(
					video->swsContext,
					(const uint8_t *const *)(video->frame->data),
					video->frame->linesize,
					0,
					video->codecContext->height,
					video->frameRGB->data,
					video->frameRGB->linesize
				);

				memcpy(dst, video->image, video->imageSize);

				return Video_tell(L);
			}
		}
		av_packet_unref(&packet);
	}

	return 0;
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
	{"seek", Video_seek},
	{"getDimensions", Video_getDimensions},
	{NULL, NULL}
};

static const struct luaL_Reg video_reg[] = {
	{"open", Video_open},
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
