local ffi = require("ffi")
local jit = require("jit")

ffi.cdef(require("video.headers"))

---@class video.AvcodecLibrary
---@field avcodec_alloc_context3 fun(codec: ffi.cdata*): ffi.cdata*
---@field avcodec_free_context fun(context: ffi.cdata*)
---@field avcodec_parameters_to_context fun(context: ffi.cdata*, parameters: ffi.cdata*): integer
---@field avcodec_open2 fun(context: ffi.cdata*, codec: ffi.cdata*, options: ffi.cdata*?): integer
---@field avcodec_send_packet fun(context: ffi.cdata*, packet: ffi.cdata*): integer
---@field av_packet_unref fun(packet: ffi.cdata*)
---@field avcodec_receive_frame fun(context: ffi.cdata*, frame: ffi.cdata*): integer
---@field avcodec_flush_buffers fun(context: ffi.cdata*)

---@class video.AvformatLibrary
---@field avio_alloc_context fun(buffer: ffi.cdata*, buffer_size: integer, write_flag: integer, opaque: ffi.cdata*, read_packet: function, write_packet: function?, seek: function): ffi.cdata*
---@field av_free fun(pointer: ffi.cdata*)
---@field avio_context_free fun(context: ffi.cdata*)
---@field avformat_alloc_context fun(): ffi.cdata*
---@field avformat_close_input fun(context: ffi.cdata*)
---@field avformat_open_input fun(context: ffi.cdata*, url: string, input_format: ffi.cdata*?, options: ffi.cdata*?): integer
---@field avformat_find_stream_info fun(context: ffi.cdata*, options: ffi.cdata*?): integer
---@field av_find_best_stream fun(context: ffi.cdata*, media_type: integer, wanted_stream: integer, related_stream: integer, decoder: ffi.cdata*, flags: integer): integer
---@field av_read_frame fun(context: ffi.cdata*, packet: ffi.cdata*): integer
---@field av_seek_frame fun(context: ffi.cdata*, stream_index: integer, timestamp: number, flags: integer): integer

---@class video.AvutilLibrary
---@field av_malloc fun(size: integer): ffi.cdata*
---@field av_frame_alloc fun(): ffi.cdata*
---@field av_free fun(pointer: ffi.cdata*)
---@field av_image_fill_arrays fun(destination_data: ffi.cdata*, destination_linesize: ffi.cdata*, source: ffi.cdata*?, pixel_format: string, width: integer, height: integer, align: integer): integer

---@class video.SwscaleLibrary
---@field sws_getContext fun(source_width: integer, source_height: integer, source_format: integer, destination_width: integer, destination_height: integer, destination_format: string, flags: integer, source_filter: ffi.cdata*?, destination_filter: ffi.cdata*?, parameters: ffi.cdata*?): ffi.cdata*
---@field sws_freeContext fun(context: ffi.cdata*)
---@field sws_scale fun(context: ffi.cdata*, source_data: ffi.cdata*, source_linesize: ffi.cdata*, source_y: integer, source_height: integer, destination_data: ffi.cdata*, destination_linesize: ffi.cdata*): integer

---@class video.Ffmpeg
---@field AV_NOPTS_VALUE ffi.cdata*
---@field avcodec video.AvcodecLibrary
---@field avformat video.AvformatLibrary
---@field avutil video.AvutilLibrary
---@field swscale video.SwscaleLibrary
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
