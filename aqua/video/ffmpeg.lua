local ffmpeg = {}

local ffi = require("ffi")
local cdef = require("aqua.cdef")
local safelib = require("aqua.safelib")

ffmpeg.avcodec = assert(safelib.load("avcodec"))
ffmpeg.avformat = assert(safelib.load("avformat"))
ffmpeg.avutil = assert(safelib.load("avutil"))
ffmpeg.swscale = assert(safelib.load("swscale"))

ffmpeg.avformat.av_register_all()
ffmpeg.avcodec.avcodec_register_all()

return ffmpeg
