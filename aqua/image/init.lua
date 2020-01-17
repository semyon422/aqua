local ThreadPool = require("aqua.thread.ThreadPool")

local image = {}

ThreadPool.observable:add(image)

local imageDatas = {}
local images = {}
local callbacks = {}

image.getImageData = function(path)
	return imageDatas[path]
end

image.getImage = function(path)
	return images[path]
end

image.load = function(path, callback)
	if imageDatas[path] then
		return callback(imageDatas[path])
	end
	
	if not callbacks[path] then
		callbacks[path] = {}
		
		ThreadPool:execute(
			[[
				local path = ...
				if love.filesystem.exists(path) then
					local imageData = require("love.image").newImageData(...)
					thread:push({
						name = "ImageData",
						imageData = imageData,
						path = path
					})
				end
			]],
			{path}
		)
	end
	
	callbacks[path][#callbacks[path] + 1] = callback
end

image.receive = function(self, event)
	if event.name == "ImageData" then
		local path = event.path
		local imageData = event.imageData
		imageDatas[path] = imageData
		images[path] = love.graphics.newImage(imageData)
		for i = 1, #callbacks[path] do
			callbacks[path][i](imageData, images[path])
		end
		callbacks[path] = nil
	end
end

image.unload = function(path, callback)
	imageDatas[path] = nil
	images[path] = nil
	return callback()
end

return image
