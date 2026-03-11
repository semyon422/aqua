local zip = require("zip")
local zlib = require("zlib")
local ZipFilesystem = require("fs.ZipFilesystem")

local test = {}

---@param t testing.T
function test.roundtrip(t)
	local writer = zip.Writer()

	-- Add a short string (will likely be Stored)
	local str1 = "hello world!"
	writer:add("hello.txt", str1)

	-- Add a long repeating string (will likely be Deflated)
	local str2 = string.rep("abc", 1000)
	writer:add("dir/abc.txt", str2)

	-- Add empty file
	writer:add("empty.txt", "")

	-- Add UTF-8 file
	writer:add("привет/мир.txt", "русский текст")

	local zip_data = writer:finish()
	t:assert(type(zip_data) == "string", "finish() should return a string")
	t:assert(#zip_data > 0, "zip data should not be empty")

	local reader = zip.Reader(zip_data)

	-- Verify entries count
	t:eq(#reader.entries, 4)

	---@type {[string]: zip.Entry}
	local found = {}
	for _, e in ipairs(reader.entries) do
		found[e.name] = e
	end

	t:assert(found["hello.txt"])
	t:assert(found["dir/abc.txt"])
	t:assert(found["empty.txt"])
	t:assert(found["привет/мир.txt"])

	-- Verify extract
	t:eq(reader:extract("hello.txt"), str1)
	t:eq(reader:extract("dir/abc.txt"), str2)
	t:eq(reader:extract("empty.txt"), "")
	t:eq(reader:extract("привет/мир.txt"), "русский текст")
end

---@param t testing.T
function test.crc32_check(t)
	local writer = zip.Writer()
	local data = "Some test data for CRC"
	writer:add("test.bin", data)
	local zip_data = writer:finish()

	local reader = zip.Reader(zip_data)
	local entry = reader.entries[1]

	local expected_crc = zlib.crc32(0, data)
	t:eq(entry.crc32, expected_crc, "CRC32 should match")
end

---@param t testing.T
function test.filesystem(t)
	local zfs = ZipFilesystem()
	zfs:createDirectory("data/nested")
	zfs:write("data/nested/test.txt", "hello filesystem")
	zfs:write("root.txt", "at root")

	local zip_data = zfs:save()
	t:assert(#zip_data > 0)

	local zfs2 = ZipFilesystem(zip_data)
	t:eq(zfs2:read("data/nested/test.txt"), "hello filesystem")
	t:eq(zfs2:read("root.txt"), "at root")

	local items = zfs2:getDirectoryItems("data")
	t:tdeq(items, {"nested"})

	local nested_items = zfs2:getDirectoryItems("data/nested")
	t:tdeq(nested_items, {"test.txt"})
end

return test
