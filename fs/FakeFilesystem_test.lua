local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@param t testing.T
function test.create_directory(t)
	local fs = FakeFilesystem()

	t:assert(fs:createDirectory("/test"))
	t:eq(fs:getInfo("/test").type, "directory")
	t:eq(fs:getInfo("/test").size, 0)
end

---@param t testing.T
function test.write_creates_file(t)
	local fs = FakeFilesystem()

	local ok, err = fs:write("file.txt", "hello")
	if not t:assert(ok, err) then
		return
	end

	t:eq(fs:getInfo("file.txt").type, "file")
	t:eq(fs:getInfo("file.txt").size, 5)
	t:eq(fs:read("file.txt"), "hello")
end

---@param t testing.T
function test.dir_struct(t)
	local fs = FakeFilesystem()

	t:assert(fs:createDirectory("/test/subdir"))
	t:assert(fs:createDirectory("/test"))
	t:assert(fs:createDirectory("/test/subdir"))
	t:assert(fs:write("/test/file.txt", ""))
	t:assert(fs:write("/test/subdir/file2.txt", "data"))
	t:eq(#fs:getDirectoryItems("/test"), 2)
	t:eq(#fs:getDirectoryItems("/test/subdir"), 1)
end

---@param t testing.T
function test.error_cases(t)
	local fs = FakeFilesystem()

	t:assert(fs:createDirectory("/test/subdir"))
	t:assert(fs:createDirectory("/test/subdir"))

	t:assert(not fs:write("/test/subdir", "data"))
	t:assert(not fs:read("/test/subdir"))
end

---@param t testing.T
function test.remove_operations(t)
	local fs = FakeFilesystem()

	t:assert(fs:createDirectory("/test"))
	t:assert(fs:createDirectory("/test/subdir"))
	t:assert(fs:write("/test/subdir/file.txt", "data"))

	t:assert(not fs:remove("/test/subdir"))
	t:assert(fs:remove("/test/subdir/file.txt"))
	t:assert(fs:remove("/test/subdir"))
	t:assert(fs:remove("/test"))
	t:eq(#fs:getDirectoryItems("/"), 0)
end

---@param t testing.T
function test.get_directory_items_sorted(t)
	local fs = FakeFilesystem()

	-- Create test structure
	fs:createDirectory("/test")
	fs:write("/test/b_file.txt", "")
	fs:write("/test/a_file.txt", "")
	fs:createDirectory("/test/z_dir")
	fs:createDirectory("/test/a_dir")
	fs:write("/test/c_file.txt", "")

	local items = fs:getDirectoryItems("/test")
	t:tdeq(items, {
		"a_dir", -- directories first
		"z_dir", -- sorted alphabetically
		"a_file.txt", -- then files
		"b_file.txt", -- sorted alphabetically
		"c_file.txt",
	})
end

return test
