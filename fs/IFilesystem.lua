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

return IFilesystem
