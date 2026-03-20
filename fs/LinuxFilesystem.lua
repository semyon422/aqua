local ffi = require("ffi")
local bit = require("bit")
local IFilesystem = require("fs.IFilesystem")

ffi.cdef [[
	typedef long time_t;
	typedef long off_t;

	struct stat {
		unsigned long st_dev;
		unsigned long st_ino;
		unsigned long st_nlink;
		unsigned int st_mode;
		unsigned int st_uid;
		unsigned int st_gid;
		int __pad0;
		unsigned long st_rdev;
		off_t st_size;
		long st_blksize;
		long st_blocks;
		long st_atime;
		unsigned long st_atime_nsec;
		long st_mtime;
		unsigned long st_mtime_nsec;
		long st_ctime;
		unsigned long st_ctime_nsec;
		long __unused[3];
	};

	int stat(const char *path, struct stat *buf);
	int mkdir(const char *pathname, unsigned int mode);
	int rmdir(const char *pathname);
	int unlink(const char *pathname);

	typedef struct DIR DIR;
	struct dirent {
		unsigned long d_ino;
		off_t d_off;
		unsigned short d_reclen;
		unsigned char d_type;
		char d_name[256];
	};

	DIR *opendir(const char *name);
	struct dirent *readdir(DIR *dirp);
	int closedir(DIR *dirp);
]]

---@class fs.LinuxStat
---@field st_dev integer
---@field st_ino integer
---@field st_nlink integer
---@field st_mode integer
---@field st_uid integer
---@field st_gid integer
---@field __pad0 integer
---@field st_rdev integer
---@field st_size integer
---@field st_blksize integer
---@field st_blocks integer
---@field st_atime integer
---@field st_atime_nsec integer
---@field st_mtime integer
---@field st_mtime_nsec integer
---@field st_ctime integer
---@field st_ctime_nsec integer
---@field __unused {[integer]: integer}

---@class fs.LinuxDirEnt
---@field d_ino integer
---@field d_off integer
---@field d_reclen integer
---@field d_type integer
---@field d_name ffi.cdata*

---@class fs.LinuxFilesystem: fs.IFilesystem
---@operator call: fs.LinuxFilesystem
local LinuxFilesystem = IFilesystem + {}

local S_IFMT = 0xf000
local S_IFDIR = 0x4000
local S_IFREG = 0x8000
local S_IFLNK = 0xa000

---@param path string
---@param info? table
---@return fs.FileInfo?
function LinuxFilesystem:getInfo(path, info)
	local buf = ffi.new("struct stat")
	if ffi.C.stat(path, buf) ~= 0 then
		return
	end

	---@cast buf -ffi.cdata*, +fs.LinuxStat

	local type = "other"
	local mode = buf.st_mode
	local fmt = bit.band(mode, S_IFMT)
	if fmt == S_IFDIR then
		type = "directory"
	elseif fmt == S_IFREG then
		type = "file"
	elseif fmt == S_IFLNK then
		type = "symlink"
	end

	return {
		type = type,
		size = tonumber(buf.st_size),
		modtime = tonumber(buf.st_mtime)
	}
end

---@param path string
---@return boolean
function LinuxFilesystem:createDirectory(path)
	-- recursive mkdir
	local current = path:sub(1, 1) == "/" and "/" or ""
	for part in path:gmatch("[^/]+") do
		current = current .. part .. "/"
		if self:getInfo(current) == nil then
			if ffi.C.mkdir(current, 493) ~= 0 then -- 0755
				return false
			end
		end
	end
	return true
end

---@param dir string
---@return string[]
function LinuxFilesystem:getDirectoryItems(dir)
	local items = {}

	---@type ffi.cdata*
	local d = ffi.C.opendir(dir)
	if d == nil then return items end

	while true do
		---@type fs.LinuxDirEnt
		local ent = ffi.C.readdir(d)
		if ent == nil then break end
		local name = ffi.string(ent.d_name)
		if name ~= "." and name ~= ".." then
			table.insert(items, name)
		end
	end

	ffi.C.closedir(d)
	return items
end

---@param name string
---@param size? number
---@return string?
---@return string?
function LinuxFilesystem:read(name, size)
	local f = io.open(name, "rb")
	if not f then return nil, "failed to open" end
	local data = f:read(size or "*a")
	f:close()
	return data
end

---@param name string
---@param data string
---@param size? number
---@return boolean
---@return string?
function LinuxFilesystem:write(name, data, size)
	local f = io.open(name, "wb")
	if not f then return false, "failed to open" end
	f:write(data)
	f:close()
	return true
end

---@param name string
---@return boolean
function LinuxFilesystem:remove(name)
	local info = self:getInfo(name)
	if not info then return true end

	if info.type ~= "directory" then
		return ffi.C.unlink(name) == 0
	end

	local items = self:getDirectoryItems(name)
	for _, item in ipairs(items) do
		self:remove(name .. "/" .. item)
	end

	return ffi.C.rmdir(name) == 0
end

return LinuxFilesystem
