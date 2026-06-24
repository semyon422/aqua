local ok, video = pcall(require, "video")
if not ok then
	print("ImageDataDecoder: can't load video module: " .. tostring(video))
	video = nil
end

---@class aqua.ImageDataDecoder
local ImageDataDecoder = {}

---@param rgba string
---@param width integer
---@param height integer
---@return love.ImageData?
local function newImageDataFromRgba(rgba, width, height)
	local ok_image, image_data = pcall(love.image.newImageData, width, height, "rgba8", rgba)
	if ok_image then
		return image_data
	end
	print("ImageDataDecoder: can't create ImageData from ffmpeg RGBA string: " .. tostring(image_data))
end

---@param file_data love.FileData
---@param label string
---@return love.ImageData?
local function decodeWithFfmpeg(file_data, label)
	if not video or not video.decode_image then
		return
	end

	local ok_image, rgba, width, height = pcall(video.decode_image, file_data:getPointer(), file_data:getSize())
	if not ok_image then
		print("ImageDataDecoder: ffmpeg image decode failed for " .. label .. ": " .. tostring(rgba))
		return
	end
	if not rgba then
		print("ImageDataDecoder: ffmpeg image decode failed for " .. label .. ": " .. tostring(width))
		return
	end

	local image_data = newImageDataFromRgba(rgba, width, height)
	return image_data
end

---@param file_data love.FileData
---@param label string?
---@return love.ImageData?
function ImageDataDecoder.decodeFileData(file_data, label)
	label = label or tostring(file_data)
	local image_data = decodeWithFfmpeg(file_data, label)
	if image_data then
		return image_data
	end

	local ok_image, love_image_data = pcall(love.image.newImageData, file_data)
	if ok_image then
		return love_image_data
	end
	print("ImageDataDecoder: love.image failed for " .. label .. ": " .. tostring(love_image_data))
end

---@param path string
---@return love.ImageData?
function ImageDataDecoder.decodePath(path)
	local file_data = love.filesystem.newFileData(path)
	if not file_data then
		print("ImageDataDecoder: can't open file data for " .. path)
		return
	end

	return ImageDataDecoder.decodeFileData(file_data, path)
end

return ImageDataDecoder
