local aquathread = require("aqua.thread")
local bass = require("aqua.audio.bass")
local bass_assert = require("aqua.audio.bass_assert")
local bass_amplify = require("aqua.audio.bass_amplify")
local ffi = require("ffi")
local Sample = require("aqua.audio.Sample")
local StreamMemoryTempo = require("aqua.audio.StreamMemoryTempo")

local audio = {}
audio.sample_gain = 0

local SoundData = {}
audio.SoundData = SoundData

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

audio.newSoundData = function(s)
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

	if audio.sample_gain > 0 then
		bass_amplify(sample, audio.sample_gain)
	end

	return setmetatable(soundData, {__index = SoundData})
end

local newSoundDataAsync = aquathread.async(function(s, sample_gain)
	local audio = require("aqua.audio")
	audio.sample_gain = sample_gain
	return audio.newSoundData(s)
end)

audio.newSoundDataAsync = function(s)
	local soundData = newSoundDataAsync(s, audio.sample_gain)
	if not soundData then return end
	return setmetatable(soundData, {__index = SoundData})
end

audio.newAudio = function(self, soundData, mode)
	if not soundData then
		return
	end
	if mode == "bass_fx_tempo" then
		return StreamMemoryTempo:new({soundData = soundData})
	end
	return Sample:new({soundData = soundData})
end

return audio
