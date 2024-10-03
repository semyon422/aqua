local ffi = require("ffi")

local _zlib = ffi.load("z")
-- http://zlib.net/zpipe.c
-- /usr/include/zlib.h

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

local zlib = {}

---@param dst_p ffi.cdata*
---@param dst_size number
---@param src_p string|ffi.cdata*
---@param src_size number
---@return number
function zlib.uncompress(dst_p, dst_size, src_p, src_size)
	local out_size = ffi.new("unsigned long[1]", dst_size)
	assert(_zlib.uncompress(dst_p, out_size, src_p, src_size) == 0)
	return tonumber(out_size[0])  --[[@as integer]]
end

---@param dst_p ffi.cdata*
---@param dst_size number
---@param src_p string|ffi.cdata*
---@param src_size number
---@param level number?
---@return integer
function zlib.compress(dst_p, dst_size, src_p, src_size, level)
	local out_size = ffi.new("unsigned long[1]", dst_size)
	assert(_zlib.compress2(dst_p, out_size, src_p, src_size, level or -1) == 0)
	return tonumber(out_size[0])  --[[@as integer]]
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
	---@cast size integer
	local out = ffi.new("uint8_t[?]", size)
	size = zlib.compress(out, size, s, #s)
	return ffi.string(out, size)
end

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

---@return string
function zlib.version()
	return ffi.string(_zlib.zlibVersion())
end

---@param stream_p ffi.cdata*
---@return true?
local function update_stream(stream_p)
	if stream_p[0].avail_in == 0 then
		local next_in, avail_in = coroutine.yield("read")
		if not next_in then
			return
		end
		stream_p[0].next_in = next_in
		stream_p[0].avail_in = avail_in
	end
	if stream_p[0].avail_out == 0 then
		local next_out, avail_out = coroutine.yield("write")
		if not next_out then
			return
		end
		stream_p[0].next_out = next_out
		stream_p[0].avail_out = avail_out
	end
	assert(stream_p[0].avail_out > 0)
	return true
end

---@param level integer
function zlib.deflate_async(level)
	local finish = false
	local stream_p = ffi.new("z_stream[1]")

	local ret = _zlib.deflateInit_(stream_p, level, _zlib.zlibVersion(), ffi.sizeof("z_stream"))
	assert(ret == ret_codes.Z_OK)

	-- Z_OK, Z_STREAM_END, Z_STREAM_ERROR, Z_BUF_ERROR
	while ret ~= ret_codes.Z_STREAM_END do
		if not update_stream(stream_p) then
			_zlib.deflateEnd(stream_p)
			return
		end

		if not finish and stream_p[0].avail_in == 0 then
			finish = true
		end

		ret = _zlib.deflate(stream_p, finish and flush_values.Z_FINISH or flush_values.Z_NO_FLUSH)
		assert(ret ~= ret_codes.Z_STREAM_ERROR)
		-- Z_BUF_ERROR is ok
	end

	_zlib.deflateEnd(stream_p)
	coroutine.yield("write", stream_p[0].avail_out)
end

function zlib.inflate_async()
	local stream_p = ffi.new("z_stream[1]")

	local ret = _zlib.inflateInit_(stream_p, _zlib.zlibVersion(), ffi.sizeof("z_stream"))
	assert(ret == ret_codes.Z_OK)

	-- Z_OK, Z_STREAM_END, Z_NEED_DICT, Z_DATA_ERROR, Z_STREAM_ERROR, Z_MEM_ERROR, Z_BUF_ERROR
	while ret ~= ret_codes.Z_STREAM_END do
		if not update_stream(stream_p) then
			_zlib.inflateEnd(stream_p)
			return
		end

		ret = _zlib.inflate(stream_p, flush_values.Z_NO_FLUSH)
		assert(ret ~= ret_codes.Z_STREAM_ERROR)
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

---@param chunk_size integer
---@param filter function
---@param file_in file*
---@param file_out file*
function zlib.process_file(chunk_size, filter, file_in, file_out)
	local _in = ffi.new("unsigned char[?]", chunk_size)
	local out = ffi.new("unsigned char[?]", chunk_size)

	local has_data = false

	local co = coroutine.create(filter)

	local buf, buf_size
	while coroutine.status(co) ~= "dead" do
		local _, action, avail_out = assert(coroutine.resume(co, buf, buf_size))
		if action == "read" then
			local data = file_in:read(chunk_size)
			if data then
				ffi.copy(_in, data, #data)
				buf, buf_size = _in, #data
			else
				buf, buf_size = _in, 0
			end
		elseif action == "write" then
			if has_data then
				file_out:write(ffi.string(out, chunk_size - (avail_out or 0)))
			end
			buf, buf_size = out, chunk_size
			has_data = true
		elseif action == "error" then
			error(avail_out)
		end
	end
end

local chunk_size = 4096

---@param level integer
---@param path_in string
---@param path_out string
function zlib.deflate_file(level, path_in, path_out)
	local file_in = assert(io.open(path_in, "rb"))
	local file_out = assert(io.open(path_out, "wb"))
	zlib.process_file(chunk_size, function() zlib.deflate_async(level) end, file_in, file_out)
	file_in:close()
	file_out:close()
end

---@param path_in string
---@param path_out string
function zlib.inflate_file(path_in, path_out)
	local file_in = assert(io.open(path_in, "rb"))
	local file_out = assert(io.open(path_out, "wb"))
	zlib.process_file(chunk_size, zlib.inflate_async, file_in, file_out)
	file_in:close()
	file_out:close()
end

-- zlib.deflate_file(6, "zlib.lua", "zlib.lua.z")
-- zlib.inflate_file("zlib.lua.z", "zlib.lua.dz")

-- print(zlib.version())

return zlib
