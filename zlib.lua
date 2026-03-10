local ffi = require("ffi")

local _zlib = ffi.load("z")
-- http://zlib.net/zpipe.c
-- /usr/include/zlib.h

ffi.cdef [[
	int uncompress(char *dest, unsigned long *destLen, const char *source, unsigned long sourceLen);
	int compress2(char *dest, unsigned long *destLen, const char *source, unsigned long sourceLen, int level);
	unsigned long compressBound(unsigned long sourceLen);

	typedef void *(*alloc_func)(void *opaque, unsigned int items, unsigned int size);
	typedef void (*free_func)(void *opaque, void *address);

	const char *zlibVersion(void);

	typedef struct z_stream_s {
		const unsigned char *next_in;
		unsigned int avail_in;
		unsigned long total_in;

		unsigned char *next_out;
		unsigned int avail_out;
		unsigned long total_out;

		const char *msg;
		struct internal_state *state;

		alloc_func zalloc;
		free_func zfree;
		void *opaque;

		int data_type;
		unsigned long adler;
		unsigned long reserved;
	} z_stream;

	typedef z_stream *z_streamp;

	int deflateInit2_(z_streamp strm, int level, int method, int windowBits, int memLevel, int strategy, const char *version, int stream_size);
	int inflateInit2_(z_streamp strm, int windowBits, const char *version, int stream_size);

	int deflate(z_streamp strm, int flush);
	int deflateEnd(z_streamp strm);

	int inflate(z_streamp strm, int flush);
	int inflateEnd(z_streamp strm);

	unsigned long crc32(unsigned long crc, const unsigned char *buf, unsigned int len);
	unsigned long adler32(unsigned long adler, const unsigned char *buf, unsigned int len);
]]

local Z_DEFLATED = 8
local MAX_WBITS = 15
local DEF_MEM_LEVEL = 8
local Z_DEFAULT_STRATEGY = 0

local flush_values = {
	Z_NO_FLUSH = 0,
	Z_PARTIAL_FLUSH = 1,
	Z_SYNC_FLUSH = 2,
	Z_FULL_FLUSH = 3,
	Z_FINISH = 4,
	Z_BLOCK = 5,
	Z_TREES = 6,
}

local ret_codes = {
	Z_OK = 0,
	Z_STREAM_END = 1,
	Z_NEED_DICT = 2,
	Z_ERRNO = -1,
	Z_STREAM_ERROR = -2,
	Z_DATA_ERROR = -3,
	Z_MEM_ERROR = -4,
	Z_BUF_ERROR = -5,
	Z_VERSION_ERROR = -6,
}

local function z_assert(ok, ret)
	if ok then
		return
	end
	local code = ""
	for k, v in pairs(ret_codes) do
		if v == ret then
			code = k
			break
		end
	end
	error(code)
end

---@class zlib.z_stream
---@field avail_in integer
---@field avail_out integer
---@field next_in ffi.cdata*
---@field next_out ffi.cdata*
local z_stream = {}

---@alias zlib.level -1|0|1|2|3|4|5|6|7|8|9

local zlib = {}

zlib.MAX_WBITS = MAX_WBITS
zlib.GZIP_WBITS = MAX_WBITS + 16
zlib.RAW_WBITS = -MAX_WBITS
zlib.AUTO_WBITS = MAX_WBITS + 32

---@return string
function zlib.version()
	return ffi.string(_zlib.zlibVersion())
end

---@param crc integer?
---@param s string|ffi.cdata*
---@param size integer?
---@return integer
function zlib.crc32(crc, s, size)
	return tonumber(_zlib.crc32(crc or 0, s, size or #s)) ---@diagnostic disable-line: return-type-mismatch
end

---@param adler integer?
---@param s string|ffi.cdata*
---@param size integer?
---@return integer
function zlib.adler32(adler, s, size)
	return tonumber(_zlib.adler32(adler or 1, s, size or #s)) ---@diagnostic disable-line: return-type-mismatch
end

---@param size integer
---@return integer
function zlib.compress_bound(size)
	---@type integer
	return tonumber(_zlib.compressBound(size))
end

---@param dst_p ffi.cdata*
---@param dst_size integer
---@param src_p string|ffi.cdata*
---@param src_size integer
---@param level zlib.level?
---@return integer
function zlib.compress_ex(dst_p, dst_size, src_p, src_size, level)
	level = level or -1
	local out_size = ffi.new("unsigned long[1]", dst_size)

	---@type integer
	local ret = _zlib.compress2(dst_p, out_size, src_p, src_size, level)
	z_assert(ret == ret_codes.Z_OK, ret)

	---@type integer
	return tonumber(out_size[0])
end

---@param dst_p ffi.cdata*
---@param dst_size integer
---@param src_p string|ffi.cdata*
---@param src_size integer
---@return integer
function zlib.uncompress_ex(dst_p, dst_size, src_p, src_size)
	local out_size = ffi.new("unsigned long[1]", dst_size)

	---@type integer
	local ret = _zlib.uncompress(dst_p, out_size, src_p, src_size)
	z_assert(ret == ret_codes.Z_OK, ret)

	---@type integer
	return tonumber(out_size[0])
end

---@param s string
---@param level zlib.level?
---@return string
function zlib.compress(s, level)
	local size = zlib.compress_bound(#s)
	local out = ffi.new("char[?]", size)
	size = zlib.compress_ex(out, size, s, #s, level)
	return ffi.string(out, size)
end

---@param s string
---@param size integer?
---@return string
function zlib.uncompress(s, size)
	if not size then
		return zlib.inflate(s)
	end
	local out = ffi.new("char[?]", size)
	size = zlib.uncompress_ex(out, size, s, #s)
	return ffi.string(out, size)
end

---@param stream_p ffi.cdata*
---@return true?
local function update_stream(stream_p)
	---@type zlib.z_stream
	local stream = stream_p[0]
	if stream.avail_in == 0 then
		local next_in, avail_in = coroutine.yield("read")
		if not next_in then
			return
		end
		stream.next_in = next_in
		stream.avail_in = avail_in
	end
	if stream.avail_out == 0 then
		local next_out, avail_out = coroutine.yield("write")
		if not next_out then
			return
		end
		stream.next_out = next_out
		stream.avail_out = avail_out
	end
	assert(stream.avail_out > 0)
	return true
end

---@param level zlib.level?
---@param window_bits integer?
function zlib.deflate_async(level, window_bits)
	level = level or -1
	window_bits = window_bits or MAX_WBITS

	local finish = false
	local stream_p = ffi.new("z_stream[1]")

	---@type integer
	local ret = _zlib.deflateInit2_(stream_p, level, Z_DEFLATED, window_bits, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY, _zlib.zlibVersion(), ffi.sizeof("z_stream"))
	z_assert(ret == ret_codes.Z_OK, ret)

	-- Z_OK, Z_STREAM_END, Z_STREAM_ERROR, Z_BUF_ERROR
	while ret ~= ret_codes.Z_STREAM_END do
		if not update_stream(stream_p) then
			_zlib.deflateEnd(stream_p)
			return
		end

		if not finish and stream_p[0].avail_in == 0 then
			finish = true
		end

		---@type integer
		ret = _zlib.deflate(stream_p, finish and flush_values.Z_FINISH or flush_values.Z_NO_FLUSH)
		z_assert(ret ~= ret_codes.Z_STREAM_ERROR, ret)
		-- Z_BUF_ERROR is ok
	end

	_zlib.deflateEnd(stream_p)
	coroutine.yield("write", stream_p[0].avail_out)
end

---@param window_bits integer?
function zlib.inflate_async(window_bits)
	window_bits = window_bits or MAX_WBITS
	local stream_p = ffi.new("z_stream[1]")

	---@type integer
	local ret = _zlib.inflateInit2_(stream_p, window_bits, _zlib.zlibVersion(), ffi.sizeof("z_stream"))
	z_assert(ret == ret_codes.Z_OK, ret)

	-- Z_OK, Z_STREAM_END, Z_NEED_DICT, Z_DATA_ERROR, Z_STREAM_ERROR, Z_MEM_ERROR, Z_BUF_ERROR
	while ret ~= ret_codes.Z_STREAM_END do
		if not update_stream(stream_p) then
			_zlib.inflateEnd(stream_p)
			return
		end

		---@type integer
		ret = _zlib.inflate(stream_p, flush_values.Z_NO_FLUSH)
		z_assert(ret ~= ret_codes.Z_STREAM_ERROR, ret)
		-- Z_BUF_ERROR is ok

		if
			ret == ret_codes.Z_NEED_DICT or
			ret == ret_codes.Z_DATA_ERROR or
			ret == ret_codes.Z_MEM_ERROR
		then
			_zlib.inflateEnd(stream_p)
			coroutine.yield("error", ret)
			return
		end
	end

	_zlib.inflateEnd(stream_p)
	coroutine.yield("write", stream_p[0].avail_out)
end

---@param s string
---@param filter function
---@param chunk_size integer?
---@param ... any
---@return string
function zlib.apply_filter(s, filter, chunk_size, ...)
	chunk_size = chunk_size or 8192

	local src_p = ffi.cast("const unsigned char *", s)
	local src_size = #s

	local dst_p = ffi.new("unsigned char[?]", chunk_size)

	---@type string[]
	local out = {}

	local has_data = false

	local co = coroutine.create(filter)

	local ok, action, avail_out = coroutine.resume(co, ...)
	if not ok then
		error(action)
	end
	---@cast action "read"|"write"|"error"
	---@cast avail_out integer?

	---@type ffi.cdata*, integer
	local buf, buf_size
	while coroutine.status(co) ~= "dead" do
		if action == "read" then
			buf, buf_size = src_p, src_size
			---@type ffi.cdata*, integer
			src_p, src_size = src_p + src_size, 0
		elseif action == "write" then
			-- Logic for collecting data from the coroutine:
			-- 1. The FIRST "write" yield is just the coroutine asking for a buffer.
			--    'has_data' is false, so we don't collect anything, just set buf/size.
			-- 2. Subsequent "write" yields mean: "I've filled the buffer you gave me 
			--    last time, and here is how much space is left (avail_out)."
			--    We collect the filled portion from 'dst_p'.
			-- 3. To collect the VERY LAST chunk, the coroutine MUST yield "write" 
			--    one last time before dying (handled in deflate_async/inflate_async).
			if has_data then
				table.insert(out, ffi.string(dst_p, chunk_size - (avail_out or 0)))
			end
			buf, buf_size = dst_p, chunk_size
			has_data = true
		elseif action == "error" then
			error(avail_out)
		end
		ok, action, avail_out = coroutine.resume(co, buf, buf_size)
		if not ok then
			error(action)
		end
		---@cast action "read"|"write"|"error"
		---@cast avail_out integer?
	end

	return table.concat(out)
end

---@param s string
---@param level zlib.level?
---@param window_bits integer?
---@param chunk_size integer?
---@return string
function zlib.deflate(s, level, window_bits, chunk_size)
	return zlib.apply_filter(s, zlib.deflate_async, chunk_size, level, window_bits)
end

---@param s string
---@param window_bits integer?
---@param chunk_size integer?
---@return string
function zlib.inflate(s, window_bits, chunk_size)
	return zlib.apply_filter(s, zlib.inflate_async, chunk_size, window_bits)
end

---@param s string
---@param level zlib.level?
---@param chunk_size integer?
---@return string
function zlib.deflate_raw(s, level, chunk_size)
	return zlib.deflate(s, level, zlib.RAW_WBITS, chunk_size)
end

---@param s string
---@param chunk_size integer?
---@return string
function zlib.inflate_raw(s, chunk_size)
	return zlib.inflate(s, zlib.RAW_WBITS, chunk_size)
end

---@param s string
---@param level zlib.level?
---@param chunk_size integer?
---@return string
function zlib.gzip(s, level, chunk_size)
	return zlib.deflate(s, level, zlib.GZIP_WBITS, chunk_size)
end

---@param s string
---@param chunk_size integer?
---@return string
function zlib.gunzip(s, chunk_size)
	return zlib.inflate(s, zlib.AUTO_WBITS, chunk_size)
end

return zlib
