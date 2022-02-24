local ffi = require("ffi")

ffi.cdef(require("aqua.video.headers"))

local ffmpeg = {}

local dl = require("aqua.dl")

ffmpeg.avcodec = ffi.load(dl.get("avcodec"))
ffmpeg.avformat = ffi.load(dl.get("avformat"))
ffmpeg.avutil = ffi.load(dl.get("avutil"))
ffmpeg.swscale = ffi.load(dl.get("swscale"))

return ffmpeg
