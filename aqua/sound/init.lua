local ThreadPool = require("aqua.thread.ThreadPool")
local SoundData = require("aqua.sound.SoundData")

local sound = {}

local soundDatas = {}
local callbacks = {}

sound.getSoundData = function(path)
	return soundDatas[path]
end

sound.loadSoundData = function(path, callback)
	if soundDatas[path] then
		return callback(soundDatas[path])
	end
	
	if not callbacks[path] then
		callbacks[path] = {}
		
		ThreadPool:execute(
			[[
				local bass = require("aqua.audio.bass")
				bass.init()
				local file = love.filesystem.newFile(...)
				file:open("r")
				local sample = bass.BASS_SampleLoad(true, file:read(), 0, file:getSize(), 65535, 0)
				file:close()
				return sample
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

sound.unloadSoundData = function(path, callback)
	if soundDatas[path] then
		return ThreadPool:execute(
			[[
				local bass = require("aqua.audio.bass")
				bass.init()
				return bass.BASS_SampleFree(...)
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
