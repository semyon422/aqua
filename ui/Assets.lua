local class = require("class")
local Path = require("Path")

---@class ui.Assets
---@operator call: ui.Assets
---@field images {[string]: love.Image}
local Assets = class()

local audio_extensions = { ".wav", ".ogg", ".mp3" }
local image_extensions = { ".png", ".jpg", ".jpeg", ".bmp", ".tga" }

---@param directory string
function Assets:new(directory)
	self.empty_image = love.graphics.newCanvas(1, 1)
	self.directory = directory
	self.images = {}
	self.file_list = {}
	self:populateFileList("", 1)
end

local max_depth = 5

---@param path string
---@param depth number
function Assets:populateFileList(path, depth)
	if depth > max_depth then
		return
	end

	local full_path = Path(self.directory) .. path
	local files = love.filesystem.getDirectoryItems(tostring(full_path))

	for _, filename in ipairs(files) do
		local full_filepath = full_path .. filename
		local local_path = Path(path) .. filename
		local info = love.filesystem.getInfo(tostring(full_filepath))

		if info and info.type == "directory" then
			self:populateFileList(tostring(local_path), depth + 1)
		elseif info and info.type == "file" then
			self.file_list[tostring(local_path):lower()] = tostring(full_filepath)
		end
	end
end

---@param filepath string
---@return string?
function Assets:findImage(filepath)
	for _, format in ipairs(image_extensions) do
		local double = self.file_list[(filepath .. "@2x" .. format):lower()]
		if double then
			return double
		end
		local normal = self.file_list[(filepath .. format):lower()]
		if normal then
			return normal
		end
	end
end

---@param filepath string
---@return love.Image
function Assets:loadImage(filepath)
	if self.images[filepath] then
		return self.images[filepath]
	end

	local image_path = self:findImage(filepath)

	if not image_path then
		return self.empty_image
	end

	local success, result = pcall(love.graphics.newImage, image_path)

	if not success then
		return self.empty_image
	end

	self.file_list[filepath] = result
	return result
end

return Assets
