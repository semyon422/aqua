local ThreadPool = require("aqua.thread.ThreadPool")

local file = {}

local fileDatas = {}
local callbacks = {}

file.get = function(path)
	return fileDatas[path]
end

file.new = function(path, name)
	local newFileData = love.filesystem.newFileData
	local fileData
	if name then
		fileData = newFileData(path, name)
	else
		fileData = newFileData(path)
	end
	fileDatas[path] = fileData
	return fileData
end

file.free = function(path)
	fileDatas[path] = nil
end

file.load = function(path, callback)
	if fileDatas[path] then
		return callback(fileDatas[path])
	end

	if not callbacks[path] then
		callbacks[path] = {}

		ThreadPool:execute({
			f = function(params)
				local path = params.params
				local info = love.filesystem.getInfo(path)
				if info then
					local fileData = love.filesystem.newFileData(path)
					return {
						fileData = fileData,
						path = path
					}
				end
			end,
			params = {
				path = path
			},
			result = file.receive
		})
	end

	callbacks[path][#callbacks[path] + 1] = callback
end

file.receive = function(event)
	local fileData = event.fileData
	local path = event.path
	fileDatas[path] = fileData
	for i = 1, #callbacks[path] do
		callbacks[path][i](fileData)
	end
	callbacks[path] = nil
end

file.unload = function(path, callback)
	fileDatas[path] = nil
	return callback()
end

return file
