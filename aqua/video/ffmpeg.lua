local ffmpeg = {}

local ffi = require("ffi")
local cdef = require("aqua.cdef")

ffmpeg.avcodec = ffi.load("avcodec-58")
ffmpeg.avformat = ffi.load("avformat-58")
ffmpeg.avutil = ffi.load("avutil-56")
ffmpeg.swscale = ffi.load("swscale-5")

ffmpeg.avformat.av_register_all()
ffmpeg.avcodec.avcodec_register_all()

return ffmpeg
