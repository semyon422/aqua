local ffi = require("ffi")
local Timer = require("aqua.util.Timer")
local Class = require("aqua.util.Class")
local ffmpeg = require("aqua.video.ffmpeg")

local avcodec = ffmpeg.avcodec
local avformat = ffmpeg.avformat
local avutil = ffmpeg.avutil
local swscale = ffmpeg.swscale

local Video = Class:new()

Video.construct = function(self)
	self.timer = Timer:new()
	self.videoTime = 0
end

Video.load = function(self, path)
	self.formatContext = ffi.new("AVFormatContext*[1]")
	self.formatContext[0] = avformat.avformat_alloc_context()
	assert(avformat.avformat_open_input(self.formatContext, path, nil, nil) == 0)

	ffi.gc(self.formatContext, avformat.avformat_close_input)

	assert(avformat.avformat_find_stream_info(self.formatContext[0], nil) == 0)

	self.codec = ffi.new('const AVCodec*[1]')
	self.streamIndex = avformat.av_find_best_stream(
		self.formatContext[0], "AVMEDIA_TYPE_VIDEO", -1, -1, self.codec, 0
	)
	self.stream = self.formatContext[0].streams[self.streamIndex]

	self.codecContext = avcodec.avcodec_alloc_context3(self.codec[0])
	avcodec.avcodec_parameters_to_context(self.codecContext, self.stream.codecpar)
	assert(avcodec.avcodec_open2(self.codecContext, self.codec[0], nil) == 0)

	ffi.gc(self.codecContext, avcodec.avcodec_close)

	local codecContext = self.codecContext

	self.frame = avutil.av_frame_alloc()
	self.frameRGB = avutil.av_frame_alloc()
	assert(self.frame)
	assert(self.frameRGB)
	ffi.gc(self.frame, avutil.av_free)
	ffi.gc(self.frameRGB, avutil.av_free)

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

	self.sws_ctx = swscale.sws_getContext(
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
	)
	ffi.gc(self.sws_ctx, swscale.sws_freeContext)
end

Video.unload = function(self) end

Video.play = function(self)
	self.timer:play()
end

Video.pause = function(self)
	self.timer:pause()
end

Video.setRate = function(self, rate)
	self.timer:setRate(rate)
end

Video.getTime = function(self)
	local effortts = self.frame.best_effort_timestamp
	local timeBase = self.stream.time_base

	if effortts < 0 then return 0 end
	if not self.videoStartTime then
		self.videoStartTime = effortts
	end
	if effortts >= self.videoStartTime then
		return tonumber(effortts - self.videoStartTime)
			/ timeBase.den * timeBase.num
	end

	return self.videoTime
end

local packet = ffi.new("AVPacket[1]")
Video.readFrame = function(self)
	while avformat.av_read_frame(self.formatContext[0], packet) == 0 do
		if packet[0].stream_index == self.streamIndex then
			self.videoTime = self:getTime()

			avcodec.avcodec_send_packet(
				self.codecContext,
				packet
			)
			local ret = avcodec.avcodec_receive_frame(
				self.codecContext,
				self.frame
			)
			avcodec.av_packet_unref(packet)
			if ret >= 0 then
				swscale.sws_scale(
					self.sws_ctx,
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

	return false
end

Video.rewind = function(self)
	avformat.av_seek_frame(self.formatContext[0], self.streamIndex, 0, 1)

	if self.image.refresh then
		self.image:refresh()
	else
		self.image:replacePixels(self.imageData)
	end
end

Video.update = function(self, dt)
	self.timer:update(dt)

	repeat until not (self.timer:getTime() >= self.videoTime and self:readFrame())

	if self.image.refresh then
		self.image:refresh()
	else
		self.image:replacePixels(self.imageData)
	end
end

return Video
