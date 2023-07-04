local ffi = require("ffi")
local jit = require("jit")

ffi.cdef(require("video.headers"))

local ffmpeg = {}

if jit.os == "Windows" then
	ffmpeg.avcodec = ffi.load("avcodec-59.dll")
	ffmpeg.avformat = ffi.load("avformat-59.dll")
	ffmpeg.avutil = ffi.load("avutil-57.dll")
	ffmpeg.swscale = ffi.load("swscale-6.dll")
else
	ffmpeg.avcodec = ffi.load("avcodec")
	ffmpeg.avformat = ffi.load("avformat")
	ffmpeg.avutil = ffi.load("avutil")
	ffmpeg.swscale = ffi.load("swscale")
end

return ffmpeg
