local ThreadPool = require("aqua.thread.ThreadPool")

local image = {}

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
				if love.filesystem.exists(...) then
					return require("love.image").newImageData(...)
				end
			]],
			{path},
			function(result)
				if result[1] and result[2] then
					imageDatas[path] = result[2]
					images[path] = love.graphics.newImage(result[2])
				end
				for i = 1, #callbacks[path] do
					callbacks[path][i](imageDatas[path], images[path])
				end
				callbacks[path] = nil
			end
		)
	end
	
	callbacks[path][#callbacks[path] + 1] = callback
end

image.unload = function(path, callback)
	imageDatas[path] = nil
	images[path] = nil
	return callback()
end

return image
