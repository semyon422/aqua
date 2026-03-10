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
function test.streaming_edge_case(t)
	-- This test uses 1-byte chunks to force frequent yielding.
	-- If there is a bug in apply_filter (missing the last chunk), this will fail.
	local test_string = ("abcdefghijklmnopqrstuvwxyz"):rep(10)
	local compressed = zlib.deflate(test_string, nil, nil, 1)
	local decompressed = zlib.inflate(compressed, nil, 1)
	t:eq(#decompressed, #test_string, "Decompressed length mismatch")
	t:eq(decompressed, test_string, "Decompression content mismatch")
end

---@param t testing.T
function test.data_loss_proof(t)
	-- Use random data to ensure no compression patterns hide the bug.
	-- If the last chunk is lost, the CRC will definitely mismatch.
	math.randomseed(42)
	local data = {}
	for i = 1, 100 do data[i] = string.char(math.random(0, 255)) end
	local test_string = table.concat(data)
	
	local compressed = zlib.deflate(test_string, nil, nil, 5)
	local decompressed = zlib.inflate(compressed, nil, 5)
	
	t:eq(#decompressed, #test_string, "Length mismatch - potential trailing data loss")
	t:eq(zlib.crc32(nil, decompressed), zlib.crc32(nil, test_string), "CRC mismatch - data was corrupted or truncated")
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
