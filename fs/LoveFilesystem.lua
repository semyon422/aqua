local IFilesystem = require("fs.IFilesystem")

---@class fs.LoveFilesystem: fs.IFilesystem
---@operator call: fs.LoveFilesystem
local LoveFilesystem = IFilesystem + {}

---@param path string
---@param info? table
---@return fs.FileInfo?
function LoveFilesystem:getInfo(path, info)
	return love.filesystem.getInfo(path, info)
end

---@param path string
---@return boolean
function LoveFilesystem:createDirectory(path)
	return love.filesystem.createDirectory(path)
end

---@param dir string
---@return string[]
function LoveFilesystem:getDirectoryItems(dir)
	return love.filesystem.getDirectoryItems(dir)
end

---@param name string
---@param size? number
---@return string?
---@return string?
function LoveFilesystem:read(name, size)
	local content, err = love.filesystem.read(name, size)
	if not content then
		---@cast err -number, +string
		return nil, err
	end
	return content
end

---@param name string
---@param data string
---@param size? number
---@return boolean
---@return string
function LoveFilesystem:write(name, data, size)
	return love.filesystem.write(name, data, size)
end

---@param name string
---@return boolean
function LoveFilesystem:remove(name)
	return love.filesystem.remove(name)
end

---@param name string
---@return boolean
function LoveFilesystem:createDirectory(name)
	return love.filesystem.createDirectory(name)
end

return LoveFilesystem
