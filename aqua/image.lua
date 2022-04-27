local aquathread = require("aqua.thread")

local image = {}

local imageDatas = {}
local images = {}
local callbacks = {}

image.getImage = function(path)
	return images[path]
end

image.load = function(path, callback)
	if imageDatas[path] then
		return callback(imageDatas[path])
	end

	if not callbacks[path] then
		callbacks[path] = {}

		aquathread.run(function(path)
			require("love.image")
			local info = love.filesystem.getInfo(path)
			if not info then
				return
			end
			local status, err = pcall(love.image.newImageData, path)
			if status then
				return err
			end
		end, {path}, function(imageData)
			imageDatas[path] = imageData
			if imageData then
				images[path] = love.graphics.newImage(imageData)
			end
			for _, cb in ipairs(callbacks[path]) do
				cb(imageData, images[path])
			end
			callbacks[path] = nil
		end)
	end

	table.insert(callbacks[path], callback)
end

image.unload = function(path)
	if imageDatas[path] then
		imageDatas[path]:release()
		imageDatas[path] = nil
	end
	if images[path] then
		images[path]:release()
		images[path] = nil
	end
end

return image
