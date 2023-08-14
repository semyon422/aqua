local ffi = require("ffi")
local bit = require("bit")
local ffmpeg = require("video.ffmpeg")
local avbuf = require("video.avbuf")

local avcodec = ffmpeg.avcodec
local avformat = ffmpeg.avformat
local avutil = ffmpeg.avutil
local swscale = ffmpeg.swscale

local video = {}

local Video = {}
local mt = {__index = Video}

local buffer_size = 8192

video.open = function(ptr, size)
	local self = setmetatable({}, mt)

	self.buffer = avutil.av_malloc(buffer_size)  -- don't gc because of IOContext will do it
	assert(self.buffer ~= nil)

	self.buf = ffi.new("Avbuf[1]")
	self.buf[0].offset = 0
	self.buf[0].ptr = ptr
	self.buf[0].size = size

	self.ioContext = ffi.new("AVIOContext*[1]")
	self.ioContext[0] = avformat.avio_alloc_context(
		self.buffer,
		buffer_size,
		0,
		self.buf,
		avbuf.Avbuf_read,
		nil,
		avbuf.Avbuf_seek
	)
	assert(self.ioContext[0] ~= nil)
	ffi.gc(self.ioContext, function()
		if self.ioContext[0].buffer ~= nil then
			avformat.av_free(self.ioContext[0].buffer)
		end
		avformat.avio_context_free(self.ioContext)
	end)

	self.formatContext = ffi.new("AVFormatContext*[1]")
	self.formatContext[0] = avformat.avformat_alloc_context()
	assert(self.formatContext[0] ~= nil)
	ffi.gc(self.formatContext, avformat.avformat_close_input)

	self.formatContext[0].pb = self.ioContext[0]
	self.formatContext[0].flags = bit.bor(self.formatContext[0].flags, 0x0080)  -- AVFMT_FLAG_CUSTOM_IO

	assert(avformat.avformat_open_input(self.formatContext, "", nil, nil) == 0)
	assert(avformat.avformat_find_stream_info(self.formatContext[0], nil) == 0)

	self.codec = ffi.new("const AVCodec*[1]")
	self.streamIndex = avformat.av_find_best_stream(
		self.formatContext[0], 0, -1, -1, self.codec, 0
	)
	assert(self.streamIndex >= 0)
	self.stream = self.formatContext[0].streams[self.streamIndex]

	self.codecContext = avcodec.avcodec_alloc_context3(self.codec[0])
	assert(self.codecContext ~= nil)
	assert(avcodec.avcodec_open2(self.codecContext, self.codec[0], nil) == 0)

	avcodec.avcodec_parameters_to_context(self.codecContext, self.stream.codecpar)

	ffi.gc(self.codecContext, avcodec.avcodec_close)

	local codecContext = self.codecContext

	self.frame = ffi.gc(avutil.av_frame_alloc(), avutil.av_free)
	self.frameRGB = ffi.gc(avutil.av_frame_alloc(), avutil.av_free)

	self.imageSize = avutil.av_image_fill_arrays(
		self.frameRGB.data,
		self.frameRGB.linesize,
		nil,
		"AV_PIX_FMT_RGBA",
		codecContext.width,
		codecContext.height,
		1
	)
	assert(self.imageSize >= 0)

	self.image = ffi.new("uint8_t[?]", self.imageSize)

	assert(avutil.av_image_fill_arrays(
		self.frameRGB.data,
		self.frameRGB.linesize,
		self.image,
		"AV_PIX_FMT_RGBA",
		codecContext.width,
		codecContext.height,
		1
	) >= 0)

	self.swsContext = ffi.gc(swscale.sws_getContext(
		codecContext.width,
		codecContext.height,
		codecContext.pix_fmt,
		codecContext.width,
		codecContext.height,
		"AV_PIX_FMT_RGBA",
		2,
		nil,
		nil,
		nil
	), swscale.sws_freeContext)

	return self
end

function Video:close() end

function Video:getDimensions()
	local cctx = self.codecContext
	return tonumber(cctx.width), tonumber(cctx.height)
end

function Video:tell()
	local effort = self.frame.best_effort_timestamp
	local base = self.stream.time_base

	if effort < 0 then
		return 0
	end

	return tonumber(effort - self.stream.start_time) * base.num / base.den
end

local packet = ffi.new("AVPacket[1]")
function Video:read(dst)
	while avformat.av_read_frame(self.formatContext[0], packet) == 0 do
		if packet[0].stream_index == self.streamIndex then
			avcodec.avcodec_send_packet(self.codecContext, packet)
			avcodec.av_packet_unref(packet)

			if avcodec.avcodec_receive_frame(self.codecContext, self.frame) == 0 then
				swscale.sws_scale(
					self.swsContext,
					ffi.cast("const uint8_t * const *", self.frame.data),
					self.frame.linesize,
					0,
					self.codecContext.height,
					self.frameRGB.data,
					self.frameRGB.linesize
				)

				ffi.copy(dst, self.image, self.imageSize)

				return self:tell()
			end
		end
		avcodec.av_packet_unref(packet)
	end
end

function Video:seek(time)
	local stream = self.stream
	local base = self.stream.time_base

	local ts = time * base.den / base.num - stream.start_time
	local cts = self.frame.best_effort_timestamp - stream.start_time

	local flags = 4  -- AVSEEK_FLAG_ANY
	if cts > ts then
		flags = bit.bor(flags, 1)  -- AVSEEK_FLAG_BACKWARD
	end

	avformat.av_seek_frame(
		self.formatContext[0],
		self.streamIndex,
		ts,
		flags
	)
	avcodec.avcodec_flush_buffers(self.codecContext);
end

return video
