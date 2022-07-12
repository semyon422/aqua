local aquathread = require("aqua.thread")
local bass = require("aqua.audio.bass")
local bass_assert = require("aqua.audio.bass_assert")
local ffi = require("ffi")

local sound = {}
sound.sample_gain = 0

local SoundData = {}
sound.SoundData = SoundData

local info = ffi.new("BASS_SAMPLE")
SoundData.load = function(self)
	local fileData = self.fileData

	local sample = bass.BASS_SampleLoad(true, fileData:getFFIPointer(), 0, fileData:getSize(), 65535, 0)
	bass_assert(sample ~= 0)
	self.sample = sample
	self.fileData:release()
	self.fileData = nil

	bass_assert(bass.BASS_SampleGetInfo(sample, info) == 1)
	self.info = {
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

	if self.sample_gain > 0 then
		local buffer = ffi.new("int16_t[?]", math.ceil(info.length / 2))
		bass_assert(bass.BASS_SampleGetData(sample, buffer) == 1)

		local amp = math.exp(self.sample_gain / 20 * math.log(10))
		for i = 0, info.length / 2 - 1 do
			buffer[i] = math.min(math.max(buffer[i] * amp, -32768), 32767)
		end
		bass_assert(bass.BASS_SampleSetData(sample, buffer) == 1)
	end
end

SoundData.release = function(self)
	assert(bass.BASS_SampleGetChannels(self.sample, nil) == 0, "Sample is still used")
	bass_assert(bass.BASS_SampleFree(self.sample) == 1)
end

sound.newSoundData = function(s)
	local fileData = s
	if type(s) == "string" then
		fileData = love.filesystem.newFileData(s)
	end

	local soundData = setmetatable({
		fileData = fileData,
		sample_gain = sound.sample_gain,
	}, {__index = SoundData})
	soundData:load()

	return soundData
end

local newSoundDataAsync = aquathread.async(function(s, sample_gain)
	local sound = require("aqua.sound")
	sound.sample_gain = sample_gain
	return sound.newSoundData(s)
end)

sound.newSoundDataAsync = function(s)
	local soundData = newSoundDataAsync(s, sound.sample_gain)
	return setmetatable(soundData, {__index = SoundData})
end

return sound
