local class = require("class")
local audio = require("audio")
local Path = require("Path")

---@class ui.Assets
---@operator call: ui.Assets
---@field images {[string]: love.Image}
---@field sounds {[string]: audio.Source }
local Assets = class()

local audio_extensions = { ".wav", ".ogg", ".mp3" }
local image_extensions = { ".png", ".jpg", ".jpeg", ".bmp", ".tga" }
local empty_image = love.graphics.newCanvas(1, 1)

---@return love.Image
function Assets.getEmptyImage()
	return empty_image
end

---@param directories string[]
function Assets:new(directories)
	self.images = {}
	self.sounds = {}
	self.file_list = {}

	for _, root in ipairs(directories) do
		self:populateFileList(root, "", 1)
	end
end

local max_depth = 5

---@param path string
---@param depth number
function Assets:populateFileList(root, path, depth)
	if depth > max_depth then
		return
	end

	local full_path = Path(root) .. path
	local files = love.filesystem.getDirectoryItems(tostring(full_path))

	for _, filename in ipairs(files) do
		local full_filepath = full_path .. filename
		local local_path = Path(path) .. filename
		local info = love.filesystem.getInfo(tostring(full_filepath))

		if info and info.type == "directory" then
			self:populateFileList(root, tostring(local_path), depth + 1)
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
---@return string?
function Assets:findSound(filepath)
	for _, format in ipairs(audio_extensions) do
		local audio_file = self.file_list[(filepath .. format):lower()]

		if audio_file then
			return audio_file
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
		return empty_image
	end

	local success, result = pcall(love.graphics.newImage, image_path)

	if not success then
		return empty_image
	end

	self.file_list[filepath] = result
	return result
end

---@param sound_path string
---@return audio.SoundData
local function getSoundData(sound_path)
	local file_data = love.filesystem.newFileData(sound_path)
	return audio.SoundData(file_data:getFFIPointer(), file_data:getSize())
end

---@param filepath string
---@param use_sound_data boolean?
---@return audio.Source?
--- Note: use_sound_data for loading audio from mounted directories (moddedgame/charts)
function Assets:loadSound(filepath, use_sound_data)
	if self.sounds[filepath] then
		return self.sounds[filepath]
	end

	local path = self:findSound(filepath)

	if not path then
		return
	end

	if use_sound_data then
		local success, result = pcall(audio.newSource, getSoundData(path))

		if success then
			self.sounds[filepath] = result
			return result
		end
	end

	local info = love.filesystem.getInfo(path)

	if info.size and info.size < 45 then -- Empty audio, might crash the game
		return
	end

	local success, result = pcall(audio.newFileSource, path)

	if success then
		local valid, error = pcall(result.stop, result)

		if valid then
			self.sounds[filepath] = result
			return result
		end
	end
end

return Assets
