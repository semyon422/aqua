local aquathread = require("aqua.thread")

local image = {}

local newImageDataAsync = aquathread.async(function(s)
	require("love.image")
	local status, err = pcall(love.image.newImageData, s)
	if not status then
		return status, err
	end
	return err
end)

image.newImageAsync = function(s)
	local imageData = newImageDataAsync(s)
	if not imageData then return end
	return love.graphics.newImage(imageData)
end

return image
