local ThreadPool = require("aqua.thread.ThreadPool")

local image = {}

local imageDatas = {}
local callbacks = {}

image.getImageData = function(path)
	return imageDatas[path]
end

image.loadImageData = function(path, callback)
	if imageDatas[path] then
		return imageDatas[path]
	end
	
	if not callbacks[path] then
		callbacks[path] = {}
		
		ThreadPool:execute(
			[[
				local image = require("love.image")
				return image.newImageData(...)
			]],
			{path},
			function(result)
				imageDatas[path] = result[2]
				for i = 1, #callbacks[path] do
					callbacks[path][i](imageDatas[path])
				end
				callbacks[path] = nil
			end
		)
	end
	
	callbacks[path][#callbacks[path] + 1] = callback
end

image.unloadImageData = function(path, callback)
	imageDatas[path] = nil
	return callback()
end

return image
