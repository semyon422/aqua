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

	local ok, err = fs_util.copy("ghost.txt", "target.txt", fs1, fs2)
	t:assert(not ok)
	---@cast err -?
	t:assert(err:match("Source not found"))
end

---@param t testing.T
function test.copy_with_filter(t)
	local fs1 = FakeFilesystem()
	local fs2 = FakeFilesystem()

	fs1:write("keep.lua", "yes")
	fs1:write("ignore.txt", "no")
	fs1:createDirectory("dir")
	fs1:write("dir/keep.lua", "yes2")
	fs1:write("dir/ignore.tmp", "no2")

	local function filter(path)
		return path:match("%.lua$") or fs1:getInfo(path).type == "directory"
	end

	fs_util.copy("", "out", fs1, fs2, filter)

	t:assert(fs2:getInfo("out/keep.lua"))
	t:assert(fs2:getInfo("out/dir/keep.lua"))
	t:assert(not fs2:getInfo("out/ignore.txt"))
	t:assert(not fs2:getInfo("out/dir/ignore.tmp"))
end

---@param t testing.T
function test.remove_recursive(t)
	local fs = FakeFilesystem()
	fs:createDirectory("a/b/c")
	fs:write("a/file.txt", "data")
	fs:write("a/b/c/deep.txt", "more data")

	fs_util.remove("a", fs)

	t:assert(not fs:getInfo("a"))
end

---@param t testing.T
function test.find_recursive(t)
	local fs = FakeFilesystem()
	fs:createDirectory("root/sub")
	fs:write("root/f1.txt", "1")
	fs:write("root/sub/f2.txt", "2")

	local found = {}
	fs_util.find("root", fs, function(p) table.insert(found, p) end)
	table.sort(found)

	t:tdeq(found, {"root/f1.txt", "root/sub/f2.txt"})
end

---@param t testing.T
function test.remove_empty_dirs(t)
	local fs = FakeFilesystem()
	fs:createDirectory("empty")
	fs:createDirectory("not_empty/sub")
	fs:write("not_empty/file.txt", "data")
	fs:createDirectory("nested_empty/level1/level2")

	fs_util.removeEmptyDirs("", fs)

	t:assert(not fs:getInfo("empty"))
	t:assert(not fs:getInfo("nested_empty"))
	t:assert(fs:getInfo("not_empty"))
	t:assert(fs:getInfo("not_empty/file.txt"))
	t:assert(not fs:getInfo("not_empty/sub"))
end

return test
