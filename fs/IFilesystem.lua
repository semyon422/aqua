local class = require("class")

---@alias fs.FileType
---| "file"
---| "directory"
---| "symlink"
---| "other"

---@class fs.FileInfo
---@field type fs.FileType
---@field size number
---@field modtime integer

---@class fs.IFilesystem
---@operator call: fs.IFilesystem
local IFilesystem = class()

---@param path string
---@param info? table
---@return fs.FileInfo?
function IFilesystem:getInfo(path, info)
	error("not implemented")
end

---@return string
function IFilesystem:getWorkingDirectory()
	error("not implemented")
end

---@param path string
---@return boolean
function IFilesystem:createDirectory(path)
	error("not implemented")
end

---@param dir string
---@return string[]
function IFilesystem:getDirectoryItems(dir)
	error("not implemented")
end

---@param name string
---@param size? number
---@return string?
---@return string?
function IFilesystem:read(name, size)
	error("not implemented")
end

---Reads a byte range without requiring callers to load the whole file.
---Offsets are zero-based. Implementations should override this with a seek-based read.
---@param name string
---@param offset integer
---@param size integer
---@return string?
---@return string?
function IFilesystem:readAt(name, offset, size)
	local data, err = self:read(name)
	if not data then
		return nil, err
	end
	return data:sub(offset + 1, offset + size)
end

---@param name string
---@param data string
---@param size? number
---@return boolean
---@return string?
function IFilesystem:write(name, data, size)
	error("not implemented")
end

---@param name string
---@return boolean
function IFilesystem:remove(name)
	error("not implemented")
end

---@param old_path string
---@param new_path string
---@return boolean
---@return string?
function IFilesystem:move(old_path, new_path)
	error("not implemented")
end

---@param newDir string
---@param mountPoint string
---@param appendToPath boolean?
---@return boolean?
---@return string?
function IFilesystem:mount(newDir, mountPoint, appendToPath)
	error("not implemented")
end

---@param oldDir string
---@return boolean?
---@return string?
function IFilesystem:unmount(oldDir)
	error("not implemented")
end

return IFilesystem
