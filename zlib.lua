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
	local ret, flush
	local have
	local stream_p = ffi.new("z_stream[1]")
	local _in = ffi.new("unsigned char[?]", CHUNK)
	local out = ffi.new("unsigned char[?]", CHUNK)

	ret = _zlib.deflateInit_(stream_p, level, _zlib.zlibVersion(), ffi.sizeof("z_stream"))
	lz_assert(ret, stream_p)

	repeat
		local avail_in, finish = coroutine.yield("read", _in, CHUNK)
		if not avail_in then
			_zlib.deflateEnd(stream_p)
			return
		end
		stream_p[0].avail_in = avail_in
		flush = finish and flush_values.Z_FINISH or flush_values.Z_NO_FLUSH
		stream_p[0].next_in = _in

		repeat
			stream_p[0].avail_out = CHUNK
			stream_p[0].next_out = out
			ret = _zlib.deflate(stream_p, flush)
			assert(ret ~= ret_codes.Z_STREAM_ERROR)
			have = CHUNK - stream_p[0].avail_out

			local written = coroutine.yield("write", out, have)
			if not written or written ~= have then
				_zlib.deflateEnd(stream_p)
				return
			end
		until stream_p[0].avail_out ~= 0

		assert(stream_p[0].avail_in == 0)
	until flush == flush_values.Z_FINISH
	assert(ret == ret_codes.Z_STREAM_END)

	_zlib.deflateEnd(stream_p)
end

function zlib.deflate(level)
	local _in = assert(io.open("zlib.lua", "rb"))
	local out = assert(io.open("zlib.lua.z", "wb"))

	local co = coroutine.create(deflate_async)

	local a, b = level, nil
	while coroutine.status(co) ~= "dead" do
		local _, action, buf, size = assert(coroutine.resume(co, a, b))
		if action == "read" then
			local data = _in:read(size)
			if data then
				a, b = #data, #data < size
				ffi.copy(buf, data, #data)
			else
				a, b = 0, true
			end
		elseif action == "write" then
			if out:write(ffi.string(buf, size)) then
				a, b = size, nil
			end
		end
	end
	_in:close()
	out:close()
end

local function inflate_async()
	local ret
	local have
	local stream_p = ffi.new("z_stream[1]")
	local _in = ffi.new("unsigned char[?]", CHUNK)
	local out = ffi.new("unsigned char[?]", CHUNK)

	ret = _zlib.inflateInit_(stream_p, _zlib.zlibVersion(), ffi.sizeof("z_stream"))
	lz_assert(ret, stream_p)

	repeat
		local avail_in = coroutine.yield("read", _in, CHUNK)
		if not avail_in then
			_zlib.deflateEnd(stream_p)
			return
		end
		if avail_in == 0 then
			break
		end
		stream_p[0].avail_in = avail_in
		stream_p[0].next_in = _in

		repeat
            stream_p[0].avail_out = CHUNK
            stream_p[0].next_out = out
            ret = _zlib.inflate(stream_p, flush_values.Z_NO_FLUSH)
            assert(ret ~= ret_codes.Z_STREAM_ERROR)
			if
				ret == ret_codes.Z_NEED_DICT or
				ret == ret_codes.Z_DATA_ERROR or
				ret == ret_codes.Z_DATA_ERROR
			then
				_zlib.inflateEnd(stream_p)
				return
			end
            have = CHUNK - stream_p[0].avail_out

			local written = coroutine.yield("write", out, have)
			if not written or written ~= have then
				_zlib.inflateEnd(stream_p)
				return
			end
		until stream_p[0].avail_out ~= 0
	until ret == ret_codes.Z_STREAM_END

	_zlib.deflateEnd(stream_p)

    return ret == ret_codes.Z_STREAM_END
end

function zlib.inflate()
	local _in = assert(io.open("zlib.lua.z", "rb"))
	local out = assert(io.open("zlib.lua.dz", "wb"))

	local co = coroutine.create(inflate_async)

	local a
	while coroutine.status(co) ~= "dead" do
		local _, action, buf, size = assert(coroutine.resume(co, a))
		if action == "read" then
			local data = _in:read(size)
			if data then
				a = #data
				ffi.copy(buf, data, #data)
			else
				a = 0
			end
		elseif action == "write" then
			if out:write(ffi.string(buf, size)) then
				a = size
			end
		end
	end
	_in:close()
	out:close()
end

-- zlib.deflate(6)
-- zlib.inflate()

-- print(zlib.version())

return zlib
