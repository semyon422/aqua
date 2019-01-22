local ThreadPool = require("aqua.thread.ThreadPool")
local bass = require("aqua.audio.bass")
local file = require("aqua.file")
local ffi = require("ffi")

local sound = {}

local soundDatas = {}
local callbacks = {}

sound.get = function(path)
	return soundDatas[path]
end

local newFile = love.filesystem.newFile
sound.new = function(path, fileData)
	local fileData = fileData or file.new(path)
	
	local sample = bass.BASS_SampleLoad(true, fileData.data, 0, fileData.length, 65535, 0)
	local info = ffi.new("BASS_SAMPLE")
	bass.BASS_SampleGetInfo(sample, info)
	
	return {
		sample = sample,
		info = {
			freq = info.freq,
			volume = info.volume,
			pan = info.pan,
			flags = info.flags,
			length = info.length,
			max = info.max,
			origres = info.origres,
			chans = info.chans,
			mingap = info.mingap,
			mode3d = info.mode3d,
			mindist = info.mindist,
			maxdist = info.maxdist,
			iangle = info.iangle,
			oangle = info.oangle,
			outvol = info.outvol,
			vam = info.vam,
			priority = info.priority
		}
	}
end

sound.free = function(soundData)
	return bass.BASS_SampleFree(soundData.sample)
end

sound.add = function(path, soundData)
	soundDatas[path] = soundData
end

sound.remove = function(path)
	soundDatas[path] = nil
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
				local soundData = result[2]
				sound.add(path, soundData)
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
			{soundDatas[path]},
			function(result)
				sound.remove(path)
				return callback()
			end
		)
	else
		return callback()
	end
end

return sound
