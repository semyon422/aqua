local ffi = require("ffi")
local jit = require("jit")

ffi.cdef(require("video.headers"))

local ffmpeg = {}

ffmpeg.AV_NOPTS_VALUE = 0x8000000000000000ll

if jit.os == "Windows" then
	ffmpeg.avcodec = ffi.load("avcodec-59.dll")
	ffmpeg.avformat = ffi.load("avformat-59.dll")
	ffmpeg.avutil = ffi.load("avutil-57.dll")
	ffmpeg.swscale = ffi.load("swscale-6.dll")
elseif jit.os == "OSX" then
	ffmpeg.avcodec = ffi.load("libavcodec.dylib")
	ffmpeg.avformat = ffi.load("libavformat.dylib")
	ffmpeg.avutil = ffi.load("libavutil.dylib")
	ffmpeg.swscale = ffi.load("libswscale.dylib")
else
	ffmpeg.avcodec = ffi.load("libavcodec.so.62")
	ffmpeg.avformat = ffi.load("libavformat.so.62")
	ffmpeg.avutil = ffi.load("libavutil.so.60")
	ffmpeg.swscale = ffi.load("libswscale.so.9")
end

return ffmpeg
