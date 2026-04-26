local LinuxFilesystem = require("fs.LinuxFilesystem")

local test = {}

local TEST_DIR = "tmp/fs_test"

---@param t testing.T
function test.lifecycle(t)
	local fs = LinuxFilesystem()

	-- Clean start
	fs:remove(TEST_DIR)
	fs:createDirectory(TEST_DIR)

	-- 1. Create directory
	t:assert(fs:createDirectory(TEST_DIR .. "/subdir"))
	local info = fs:getInfo(TEST_DIR .. "/subdir")
	t:assert(info)
	---@cast info -?
	t:eq(info.type, "directory")

	-- 2. Write file
	local test_file = TEST_DIR .. "/hello.txt"
	local data = "hello linux fs"
	t:assert(fs:write(test_file, data))

	-- 3. Read file
	local read_data = fs:read(test_file)
	t:eq(read_data, data)

	-- 4. Get info
	local file_info = fs:getInfo(test_file)
	t:assert(file_info)
	---@cast file_info -?
	t:eq(file_info.type, "file")
	t:eq(file_info.size, #data)
	t:assert(file_info.modtime > 0)

	-- 5. List items
	local items = fs:getDirectoryItems(TEST_DIR)
	table.sort(items) -- System order might vary
	t:tdeq(items, {"hello.txt", "subdir"})

	-- 6. Remove recursively
	t:assert(fs:remove(TEST_DIR))
	t:assert(fs:getInfo(TEST_DIR) == nil)
end

---@param t testing.T
function test.remove_unlinks_directory_symlink(t)
	local fs = LinuxFilesystem()
	local target_dir = TEST_DIR .. "_target"
	local link_dir = TEST_DIR .. "_link"

	fs:remove(link_dir)
	fs:remove(target_dir)
	fs:createDirectory(target_dir)
	fs:write(target_dir .. "/keep.txt", "data")
	local target_abs = fs:getWorkingDirectory() .. "/" .. target_dir
	t:assert(os.execute(string.format("ln -s %q %q", target_abs, link_dir)))

	local info = fs:getInfo(link_dir)
	t:assert(info)
	---@cast info -?
	t:eq(info.type, "symlink")

	t:assert(fs:remove(link_dir))
	t:assert(fs:getInfo(link_dir) == nil)
	t:assert(fs:getInfo(target_dir .. "/keep.txt") ~= nil)

	fs:remove(target_dir)
end

return test
