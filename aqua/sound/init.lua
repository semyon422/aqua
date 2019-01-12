local ThreadPool = require("aqua.thread.ThreadPool")
local SoundData = require("aqua.sound.SoundData")
local bass = require("aqua.audio.bass")

local sound = {}

local soundDatas = {}
local callbacks = {}

sound.get = function(path)
	return soundDatas[path]
end

local newFile = love.filesystem.newFile
sound.new = function(path)
	local file = newFile(path)
	file:open("r")
	local sample = bass.BASS_SampleLoad(true, file:read(), 0, file:getSize(), 65535, 0)
	file:close()
	return sample
end

sound.free = function(sample)
	return bass.BASS_SampleFree(sample)
end

sound.load = function(path, callback)
	if soundDatas[path] then
		return callback(soundDatas[path])
	end
	
	if not callbacks[path] then
		callbacks[path] = {}
		
		ThreadPool:execute(
			[[
				if love.filesystem.exists(...) then
					return require("aqua.sound").new(...)
				end
			]],
			{path},
			function(result)
				local soundData = SoundData:new()
				soundData.sample = result[2]
				soundDatas[path] = soundData
				for i = 1, #callbacks[path] do
					callbacks[path][i](soundData)
				end
				callbacks[path] = nil
			end
		)
	end
	
	callbacks[path][#callbacks[path] + 1] = callback
end

sound.unload = function(path, callback)
	if soundDatas[path] then
		return ThreadPool:execute(
			[[
				return require("aqua.sound").free(...)
			]],
			{soundDatas[path].sample},
			function(result)
				soundDatas[path] = nil
				return callback()
			end
		)
	else
		return callback()
	end
end

return sound
