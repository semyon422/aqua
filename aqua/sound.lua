local aquathread = require("aqua.thread")
local bass = require("aqua.audio.bass")
local bass_assert = require("aqua.audio.bass_assert")
local ffi = require("ffi")

local sound = {}
sound.sample_gain = 0

local SoundData = {}
sound.SoundData = SoundData

local info_fields = {
	"freq",
	"volume",
	"pan",
	"flags",
	"length",
	"max",
	"origres",
	"chans",
	"mingap",
	"mode3d",
	"mindist",
	"maxdist",
	"iangle",
	"oangle",
	"outvol",
	"vam",
	"priority",
}

local info = ffi.new("BASS_SAMPLE")

SoundData.release = function(self)
	assert(bass.BASS_SampleGetChannels(self.sample, nil) == 0, "Sample is still used")
	bass_assert(bass.BASS_SampleFree(self.sample) == 1)
end

sound.newSoundData = function(s)
	local fileData = s
	if type(s) == "string" then
		fileData = love.filesystem.newFileData(s)
	end

	local sample = bass.BASS_SampleLoad(true, fileData:getFFIPointer(), 0, fileData:getSize(), 65535, 0)
	fileData:release()

	-- bass_assert(sample ~= 0)
	if sample == 0 then
		return
	end

	local soundData = {}
	soundData.sample = sample

	bass_assert(bass.BASS_SampleGetInfo(sample, info) == 1)
	local info_table = {}
	for _, field in ipairs(info_fields) do
		info_table[field] = info[field]
	end
	soundData.info = info_table

	if sound.sample_gain > 0 then
		local buffer = ffi.new("int16_t[?]", math.ceil(info.length / 2))
		bass_assert(bass.BASS_SampleGetData(sample, buffer) == 1)

		local amp = math.exp(sound.sample_gain / 20 * math.log(10))
		for i = 0, info.length / 2 - 1 do
			buffer[i] = math.min(math.max(buffer[i] * amp, -32768), 32767)
		end
		bass_assert(bass.BASS_SampleSetData(sample, buffer) == 1)
	end

	return setmetatable(soundData, {__index = SoundData})
end

local newSoundDataAsync = aquathread.async(function(s, sample_gain)
	local sound = require("aqua.sound")
	sound.sample_gain = sample_gain
	return sound.newSoundData(s)
end)

sound.newSoundDataAsync = function(s)
	local soundData = newSoundDataAsync(s, sound.sample_gain)
	if not soundData then return end
	return setmetatable(soundData, {__index = SoundData})
end

return sound
