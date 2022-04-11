local aquathread = require("aqua.thread")
local bass = require("aqua.audio.bass")
local ffi = require("ffi")

local sound = {}

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
	fileData = fileData or love.filesystem.newFileData(path)

	local sample = bass.BASS_SampleLoad(true, fileData:getFFIPointer(), 0, fileData:getSize(), 65535, 0)
	if sample == 0 then
		return error("Error loading sample")
	end
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
			priority = info.priority,
		}
	}
end

sound.free = function(soundData)
	assert(bass.BASS_SampleGetChannels(soundData.sample, nil) == 0, "Sample is still used")
	bass.BASS_SampleFree(soundData.sample)
	soundData.fileData:release()
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

		aquathread.run(function(path, sample_gain)
			local sound = require("aqua.sound")
			sound.set_gain(sample_gain)
			local info = love.filesystem.getInfo(path)
			if not info then
				return
			end
			local status, err = xpcall(
				sound.new,
				debug.traceback,
				path
			)
			if status then
				return err
			end
		end, {path, sound.sample_gain}, function(soundData)
			sound.add(path, soundData)
			for _, cb in ipairs(callbacks[path]) do
				cb(soundData)
			end
			callbacks[path] = nil
		end)
	end

	table.insert(callbacks[path], callback)
end

sound.unload = function(path, callback)
	if soundDatas[path] then
		sound.free(soundDatas[path])
		sound.remove(path)
	end
	return callback()
end

return sound
