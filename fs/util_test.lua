local FakeFilesystem = require("fs.FakeFilesystem")
local fs_util = require("fs.util")

local test = {}

---@param t testing.T
function test.copy_file(t)
	local fs1 = FakeFilesystem()
	local fs2 = FakeFilesystem()

	fs1:write("test.txt", "hello world")

	fs_util.copy("test.txt", "copy.txt", fs1, fs2)

	t:eq(fs2:read("copy.txt"), "hello world")
end

---@param t testing.T
function test.copy_directory_recursive(t)
	local fs1 = FakeFilesystem()
	local fs2 = FakeFilesystem()

	fs1:createDirectory("dir")
	fs1:write("dir/file1.txt", "content1")
	fs1:createDirectory("dir/subdir")
	fs1:write("dir/subdir/file2.txt", "content2")

	fs_util.copy("dir", "backup", fs1, fs2)

	t:eq(fs2:read("backup/file1.txt"), "content1")
	t:eq(fs2:read("backup/subdir/file2.txt"), "content2")

	local items = fs2:getDirectoryItems("backup")
	t:tdeq(items, {"subdir", "file1.txt"}) -- FakeFilesystem sorts directories first
end

---@param t testing.T
function test.copy_to_same_fs(t)
	local fs = FakeFilesystem()

	fs:write("original.txt", "data")
	fs_util.copy("original.txt", "clone.txt", fs, fs)

	t:eq(fs:read("clone.txt"), "data")
end

---@param t testing.T
function test.copy_non_existent(t)
	local fs1 = FakeFilesystem()
	local fs2 = FakeFilesystem()

	t:has_error(function()
		fs_util.copy("ghost.txt", "target.txt", fs1, fs2)
	end)
end

return test
