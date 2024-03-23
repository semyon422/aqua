local ffi = require("ffi")
local _lz4 = ffi.load("lz4")

local LZ4F_VERSION = 100

ffi.cdef[[
typedef size_t LZ4F_errorCode_t;
typedef struct LZ4F_dctx_s LZ4F_dctx;

typedef struct {} LZ4F_decompressOptions_t; /* no options */

LZ4F_errorCode_t LZ4F_createDecompressionContext(LZ4F_dctx** dctxPtr, unsigned version);
LZ4F_errorCode_t LZ4F_freeDecompressionContext(LZ4F_dctx* dctx);

size_t LZ4F_decompress(LZ4F_dctx* dctx,
void* dstBuffer, size_t* dstSizePtr,
const void* srcBuffer, size_t* srcSizePtr,
const LZ4F_decompressOptions_t* dOptPtr);

unsigned LZ4F_isError(LZ4F_errorCode_t code);
const char* LZ4F_getErrorName(LZ4F_errorCode_t code);
]]

local lz4f = {}

local outbuff_size = 2 ^ 16  -- 64k

local function is_error(code)
	return _lz4.LZ4F_isError(0ULL + code) > 0
end
local function get_error_name(code)
	return ffi.string(_lz4.LZ4F_getErrorName(0ULL + code))
end

assert(is_error(0ULL - 4))

function lz4f.decompress(s)
	local dctx = ffi.new("LZ4F_dctx*[1]")
	local status = _lz4.LZ4F_createDecompressionContext(dctx, LZ4F_VERSION)
	if is_error(status) then
		print("LZ4F_dctx creation error:", get_error_name(status))
	end

	local dst = ffi.new("uint8_t[?]", outbuff_size)

	local src_ptr = ffi.cast("const char*", s)
	local src_end = src_ptr + #s

	local out = {}

	local ret = 1
	while true do
	-- while src_ptr < src_end and tonumber(ret) ~= 0 do
		local dst_size = ffi.new("size_t[1]", {outbuff_size})
		local src_size = ffi.new("size_t[1]", {src_end - src_ptr})
		ret = _lz4.LZ4F_decompress(dctx[0], dst, dst_size, src_ptr, src_size, nil)
		if is_error(ret) then
			print("LZ4F_dctx creation error:", get_error_name(ret))
		end
		if dst_size[0] > 0 then
			table.insert(out, ffi.string(dst, dst_size[0]))
		end
		src_ptr = src_ptr + src_size[0]
		if src_size[0] == 0 and dst_size[0] == 0 then
			break
		end
	end

	return table.concat(out)
end

return lz4f
