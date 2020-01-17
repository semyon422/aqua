local ThreadPool = require("aqua.thread.ThreadPool")

local file = {}

ThreadPool.observable:add(file)

local fileDatas = {}
local callbacks = {}

file.get = function(path)
	return fileDatas[path]
end

local newFileData = love.filesystem.newFileData
file.new = function(path, name)
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
		
		ThreadPool:execute(
			[[
				local path = ...
				if love.filesystem.exists(path) then
					local fileData = require("aqua.file").new(path)
					thread:push({
						name = "FileData",
						fileData = fileData,
						path = path
					})
				end
			]],
			{path}
		)
	end
	
	callbacks[path][#callbacks[path] + 1] = callback
end

file.receive = function(self, event)
	if event.name == "FileData" then
		local fileData = event.fileData
		local path = event.path
		fileDatas[path] = fileData
		for i = 1, #callbacks[path] do
			callbacks[path][i](fileData)
		end
		callbacks[path] = nil
	end
end

file.unload = function(path, callback)
	fileDatas[path] = nil
	return callback()
end

return file
