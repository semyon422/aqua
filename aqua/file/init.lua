local ThreadPool = require("aqua.thread.ThreadPool")

local file = {}

local fileDatas = {}
local callbacks = {}

file.get = function(path)
	return fileDatas[path]
end

local newFile = love.filesystem.newFile
file.new = function(path)
	local file = newFile(path)
	file:open("r")
	local data = file:read()
	local length = file:getSize()
	file:close()
	
	local fileData = {
		data = file:read(),
		length = file:getSize()
	}
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
				if love.filesystem.exists(...) then
					return require("aqua.file").new(...)
				end
			]],
			{path},
			function(result)
				local fileData = result[2]
				fileDatas[path] = fileData
				for i = 1, #callbacks[path] do
					callbacks[path][i](fileData)
				end
				callbacks[path] = nil
			end
		)
	end
	
	callbacks[path][#callbacks[path] + 1] = callback
end

file.unload = function(path, callback)
	fileDatas[path] = nil
	return callback()
end

return file
