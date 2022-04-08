local ThreadPool = require("aqua.thread.ThreadPool")
local bass = require("aqua.audio.bass")
local file = require("aqua.file")
local ffi = require("ffi")

local sound = {}

ThreadPool.observable:add(sound)

local soundDatas = {}
local callbacks = {}

sound.get = function(path)
	return soundDatas[path]
end

sound.sample_gain = 0
sound.set_gain = function(gain)
	sound.sample_gain = gain
end

sound.new = function(path, fileData)
	local fileData = fileData or file.new(path)

	local sample = bass.BASS_SampleLoad(true, fileData:getString(), 0, fileData:getSize(), 65535, 0)
	local info = ffi.new("BASS_SAMPLE")
	bass.BASS_SampleGetInfo(sample, info)

	if sound.sample_gain > 0 then
		local buffer = ffi.new("int16_t[?]", math.ceil(info.length / 2))
		bass.BASS_SampleGetData(sample, buffer)

		local amp = math.exp(sound.sample_gain / 20 * math.log(10))
		for i = 0, info.length / 2 - 1 do
			buffer[i] = math.min(math.max(buffer[i] * amp, -32768), 32767)
		end
		bass.BASS_SampleSetData(sample, buffer)
	end

	return {
		fileData = fileData,
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

sound.free = function(sample)
	return bass.BASS_SampleFree(sample)
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

		ThreadPool:execute({
			f = function(path, sample_gain)
				local sound = require("aqua.sound")
				sound.set_gain(sample_gain)
				local info = love.filesystem.getInfo(path)
				if info then
					local status, err = xpcall(
						sound.new,
						debug.traceback,
						path
					)
					return {
						status = status,
						soundData = err,
						path = path
					}
				end
			end,
			params = {path, sound.sample_gain},
			result = sound.receive
		})
	end

	callbacks[path][#callbacks[path] + 1] = callback
end

sound.receive = function(event)
	if event.status then
		local soundData = event.soundData
		local path = event.path
		sound.add(path, soundData)
		for i = 1, #callbacks[path] do
			callbacks[path][i](soundData)
		end
		callbacks[path] = nil
	else
		local path = event.path
		print(event.soundData)
		for i = 1, #callbacks[path] do
			callbacks[path][i]()
		end
		callbacks[path] = nil
	end
end

sound.unload = function(path, callback)
	if soundDatas[path] then
		ThreadPool:execute({
			f = function(sample)
				return require("aqua.sound").free(sample)
			end,
			params = {soundDatas[path].sample},
		})
		sound.remove(path)
	end
	return callback()
end

return sound
