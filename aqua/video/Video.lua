local ffi = require("ffi")
local Class = require("aqua.util.Class")
local ffmpeg = require("aqua.video.ffmpeg")

local avcodec = ffmpeg.avcodec
local avformat = ffmpeg.avformat
local avutil = ffmpeg.avutil
local swscale = ffmpeg.swscale

local Video = Class:new()

Video.load = function(self, path)
	self.formatContext = ffi.new("AVFormatContext*[1]")
	self.formatContext[0] = avformat.avformat_alloc_context()
	assert(avformat.avformat_open_input(self.formatContext, path, nil, nil) == 0)

	ffi.gc(self.formatContext, avformat.avformat_close_input)

	assert(avformat.avformat_find_stream_info(self.formatContext[0], nil) == 0)

	self.codec = ffi.new("const AVCodec*[1]")
	self.streamIndex = avformat.av_find_best_stream(
		self.formatContext[0], "AVMEDIA_TYPE_VIDEO", -1, -1, self.codec, 0
	)
	self.stream = self.formatContext[0].streams[self.streamIndex]

	self.codecContext = avcodec.avcodec_alloc_context3(self.codec[0])
	avcodec.avcodec_parameters_to_context(self.codecContext, self.stream.codecpar)
	assert(avcodec.avcodec_open2(self.codecContext, self.codec[0], nil) == 0)

	ffi.gc(self.codecContext, avcodec.avcodec_close)

	local codecContext = self.codecContext

	self.frame = ffi.gc(avutil.av_frame_alloc(), avutil.av_free)
	self.frameRGB = ffi.gc(avutil.av_frame_alloc(), avutil.av_free)

	self.imageData = love.image.newImageData(codecContext.width, codecContext.height)
	self.image = love.graphics.newImage(self.imageData)

	avutil.av_image_fill_arrays(
		self.frameRGB.data,
		self.frameRGB.linesize,
		ffi.cast("uint8_t*", self.imageData:getPointer()),
		"AV_PIX_FMT_RGBA",
		codecContext.width,
		codecContext.height,
		1
	)

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
end

Video.getTime = function(self)
	local effort = self.frame.best_effort_timestamp
	local base = self.stream.time_base

	if effort < 0 then return 0 end
	if not self.startTime then
		self.startTime = effort
	end
	return tonumber(effort - self.startTime) / base.den * base.num
end

local packet = ffi.new("AVPacket[1]")
Video.readFrame = function(self)
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

				return true
			end
		end
		avcodec.av_packet_unref(packet)
	end
end

Video.rewind = function(self)
	avformat.av_seek_frame(self.formatContext[0], self.streamIndex, 0, 1)
	self.image:replacePixels(self.imageData)
end

Video.seek = function(self, time)
	repeat until not (time >= self:getTime() and self:readFrame())
	self.image:replacePixels(self.imageData)
end

return Video
