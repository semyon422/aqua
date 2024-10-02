local ffi = require("ffi")

local _zlib = ffi.load("z")
-- http://zlib.net/zpipe.c

ffi.cdef[[
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

int deflateInit_(z_streamp strm, int level, const char *version, int stream_size);
int inflateInit_(z_streamp strm, const char *version, int stream_size);

int deflate(z_streamp strm, int flush);
int deflateEnd(z_streamp strm);

int inflate(z_streamp strm, int flush);
int inflateEnd(z_streamp strm);
]]

---@generic K
---@generic V
---@param t {[K]: V}
---@param v V
---@return K?
local function keyof(t, v)
	for i, _v in pairs(t) do
		if _v == v then
			return i
		end
	end
end

local zlib = {}

---@param dst_p ffi.cdata*
---@param dst_size number
---@param src_p string|ffi.cdata*
---@param src_size number
---@return number
function zlib.uncompress(dst_p, dst_size, src_p, src_size)
	local out_size = ffi.new("unsigned long[1]", dst_size)
	assert(_zlib.uncompress(dst_p, out_size, src_p, src_size) == 0)
	return tonumber(out_size[0])
end

---@param dst_p ffi.cdata*
---@param dst_size number
---@param src_p string|ffi.cdata*
---@param src_size number
---@param level number?
---@return number
function zlib.compress(dst_p, dst_size, src_p, src_size, level)
	local out_size = ffi.new("unsigned long[1]", dst_size)
	assert(_zlib.compress2(dst_p, out_size, src_p, src_size, level or -1) == 0)
	return tonumber(out_size[0])
end

---@param s string
---@param size number
---@return string
function zlib.uncompress_s(s, size)
	local out = ffi.new("uint8_t[?]", size)
	size = zlib.uncompress(out, size, s, #s)
	return ffi.string(out, size)
end

---@param s string
---@return string
function zlib.compress_s(s)
	local size = tonumber(_zlib.compressBound(#s))
	local out = ffi.new("uint8_t[?]", size)
	size = zlib.compress(out, size, s, #s)
	return ffi.string(out, size)
end

---@enum zlib.flush_values
local flush_values = {
	Z_NO_FLUSH = 0,
	Z_PARTIAL_FLUSH = 1,
	Z_SYNC_FLUSH = 2,
	Z_FULL_FLUSH = 3,
	Z_FINISH = 4,
	Z_BLOCK = 5,
	Z_TREES = 6,
}

---@enum zlib.ret_codes
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

---@return string
function zlib.version()
	return ffi.string(_zlib.zlibVersion())
end

---@param result zlib.ret_codes
---@param stream_p ffi.cdata*
---@return integer
local function lz_assert(result, stream_p)
	if result == ret_codes.Z_OK or result == ret_codes.Z_STREAM_END then
		return result
	end

	local code = keyof(ret_codes, result)
	if stream_p[0].msg == nil then
		error(code)
	end

	error(("%s: %s"):format(code, ffi.string(stream_p[0].msg)))
end

local CHUNK = 512

---@param level integer
local function deflate_async(level)
	local flush = flush_values.Z_NO_FLUSH
	local stream_p = ffi.new("z_stream[1]")

	local ret = _zlib.deflateInit_(stream_p, level, _zlib.zlibVersion(), ffi.sizeof("z_stream"))
	lz_assert(ret, stream_p)

	while ret ~= ret_codes.Z_STREAM_END do
		if stream_p[0].avail_in == 0 then
			local next_in, avail_in = coroutine.yield("read")
			if not next_in then
				_zlib.deflateEnd(stream_p)
				return
			end
			stream_p[0].next_in = next_in
			stream_p[0].avail_in = avail_in
		end
		if stream_p[0].avail_out == 0 then
			local next_out, avail_out = coroutine.yield("write")
			if not next_out then
				_zlib.deflateEnd(stream_p)
				return
			end
            stream_p[0].next_out = next_out
            stream_p[0].avail_out = avail_out
		end

		if stream_p[0].avail_in == 0 then
			flush = flush_values.Z_FINISH
		end

		ret = _zlib.deflate(stream_p, flush)
		assert(ret ~= ret_codes.Z_STREAM_ERROR)
	end

	coroutine.yield("end", stream_p[0].avail_in, stream_p[0].avail_out)

	_zlib.deflateEnd(stream_p)
end

local function inflate_async()
	local stream_p = ffi.new("z_stream[1]")

	local ret = _zlib.inflateInit_(stream_p, _zlib.zlibVersion(), ffi.sizeof("z_stream"))
	lz_assert(ret, stream_p)

	while ret ~= ret_codes.Z_STREAM_END do
		if stream_p[0].avail_in == 0 then
			local next_in, avail_in = coroutine.yield("read")
			if not next_in then
				_zlib.inflateEnd(stream_p)
				return
			end
			stream_p[0].next_in = next_in
			stream_p[0].avail_in = avail_in
		end
		if stream_p[0].avail_out == 0 then
			local next_out, avail_out = coroutine.yield("write")
			if not next_out then
				_zlib.inflateEnd(stream_p)
				return
			end
            stream_p[0].next_out = next_out
            stream_p[0].avail_out = avail_out
		end

		ret = _zlib.inflate(stream_p, flush_values.Z_NO_FLUSH)
		assert(ret ~= ret_codes.Z_STREAM_ERROR)
		if
			ret == ret_codes.Z_NEED_DICT or
			ret == ret_codes.Z_DATA_ERROR or
			ret == ret_codes.Z_MEM_ERROR
		then
			_zlib.inflateEnd(stream_p)
			return
		end
	end

	coroutine.yield("end", stream_p[0].avail_in, stream_p[0].avail_out)

	_zlib.inflateEnd(stream_p)
end

function zlib.process_file(filter, path_in, path_out)
	local file_in = assert(io.open(path_in, "rb"))
	local file_out = assert(io.open(path_out, "wb"))

	local _in = ffi.new("unsigned char[?]", CHUNK)
	local out = ffi.new("unsigned char[?]", CHUNK)

	local has_data = false

	local co = coroutine.create(filter)

	local buf, buf_size
	while coroutine.status(co) ~= "dead" do
		local _, action, avail_in, avail_out = assert(coroutine.resume(co, buf, buf_size))
		if action == "read" then
			local data = file_in:read(CHUNK)
			if data then
				ffi.copy(_in, data, #data)
				buf, buf_size = _in, #data
			else
				buf, buf_size = _in, 0
			end
		elseif action == "write" then
			if has_data then
				file_out:write(ffi.string(out, CHUNK))
			end
			buf, buf_size = out, CHUNK
			has_data = true
		elseif action == "end" then
			if avail_out > 0 then
				file_out:write(ffi.string(out, CHUNK - avail_out))
			end
		end
	end
	file_in:close()
	file_out:close()
end

function zlib.deflate(level)
	zlib.process_file(function() deflate_async(level) end, "zlib.lua", "zlib.lua.z")
end

function zlib.inflate()
	zlib.process_file(inflate_async, "zlib.lua.z", "zlib.lua.dz")
end

zlib.deflate(6)
zlib.inflate()

print(zlib.version())

return zlib
