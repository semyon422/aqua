local ffi = require("ffi")

local _zlib = ffi.load("z")

ffi.cdef([[
int uncompress(char *dest, unsigned long *destLen, const char *source, unsigned long sourceLen);
int compress2(char *dest, unsigned long *destLen, const char *source, unsigned long sourceLen, int level);
unsigned long compressBound(unsigned long sourceLen);
]])

local zlib = {}

function zlib.uncompress(dst_p, dst_size, src_p, src_size)
	local out_size = ffi.new("size_t[1]", dst_size)
	assert(_zlib.uncompress(dst_p, out_size, src_p, src_size) == 0)
	return tonumber(out_size[0])
end

function zlib.compress(dst_p, dst_size, src_p, src_size, level)
	local out_size = ffi.new("size_t[1]", dst_size)
	assert(_zlib.compress2(dst_p, out_size, src_p, src_size, level or -1) == 0)
	return tonumber(out_size[0])
end

function zlib.uncompress_s(s, size)
	local out = ffi.new("uint8_t[?]", size)
	size = zlib.uncompress(out, size, s, #s)
	return ffi.string(out, size)
end

function zlib.compress_s(s)
	local size = _zlib.compressBound(#s)
	local out = ffi.new("uint8_t[?]", size)
	size = zlib.compress(out, size, s, #s)
	return ffi.string(out, size)
end

return zlib