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

		ThreadPool:execute({
			f = function(path)
				local image = require("love.image")
				local info = love.filesystem.getInfo(path)
				if info then
					local status, err = xpcall(
						image.newImageData,
						debug.traceback,
						path
					)
					return {
						status = status,
						imageData = err,
						path = path,
					}
				end
			end,
			params = {path},
			result = image.receive
		})
	end

	callbacks[path][#callbacks[path] + 1] = callback
end

image.receive = function(event)
	local path = event.path
	if event.status then
		local imageData = event.imageData
		imageDatas[path] = imageData
		images[path] = love.graphics.newImage(imageData)
		for i = 1, #callbacks[path] do
			callbacks[path][i](imageData, images[path])
		end
	else
		print(event.imageData)
		for i = 1, #callbacks[path] do
			callbacks[path][i]()
		end
	end
	callbacks[path] = nil
end

image.unload = function(path, callback)
	imageDatas[path] = nil
	images[path] = nil
	return callback()
end

return image
