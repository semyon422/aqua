local ffmpeg = {}

local ffi = require("ffi")
local cdef = require("aqua.cdef")
local dl = require("aqua.dl")

ffmpeg.avcodec = ffi.load(dl.get("avcodec"))
ffmpeg.avformat = ffi.load(dl.get("avformat"))
ffmpeg.avutil = ffi.load(dl.get("avutil"))
ffmpeg.swscale = ffi.load(dl.get("swscale"))

ffmpeg.avformat.av_register_all()
ffmpeg.avcodec.avcodec_register_all()

return ffmpeg
