local zlib = require("zlib")

local test = {}

---@param t testing.T
function test.zlib(t)
	local test_string = ("test"):rep(100)

	-- Basic compress/uncompress
	t:eq(zlib.uncompress(zlib.compress(test_string), #test_string), test_string)

	-- Uncompress without size (uses inflate)
	t:eq(zlib.uncompress(zlib.compress(test_string)), test_string)

	-- Deflate/Inflate with chunks
	t:eq(zlib.inflate(zlib.deflate(test_string, nil, nil, 10), nil, 10), test_string)
	t:eq(zlib.inflate(zlib.deflate(test_string, 0, nil, 10), nil, 10), test_string)
	t:eq(zlib.inflate(zlib.deflate(test_string, 9, nil, 10), nil, 10), test_string)
	t:eq(zlib.inflate(zlib.deflate(test_string)), test_string)

	-- Raw deflate
	local raw = zlib.deflate_raw(test_string)
	t:eq(zlib.inflate_raw(raw), test_string)

	-- Gzip
	local gz = zlib.gzip(test_string)
	t:eq(zlib.gunzip(gz), test_string)

	-- Auto detection (zlib/gzip)
	t:eq(zlib.inflate(zlib.compress(test_string), zlib.AUTO_WBITS), test_string)
	t:eq(zlib.inflate(gz, zlib.AUTO_WBITS), test_string)
end

---@param t testing.T
function test.checksums(t)
	local test_string = "hello world"

	-- Adler32
	t:eq(zlib.adler32(nil, test_string), 436929629)
	t:eq(zlib.adler32(zlib.adler32(nil, "hello "), "world"), 436929629)

	-- CRC32
	t:eq(zlib.crc32(nil, test_string), 222957957)
	t:eq(zlib.crc32(zlib.crc32(nil, "hello "), "world"), 222957957)
end

return test
