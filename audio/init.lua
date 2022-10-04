local bass = require("audio.bass")
local bass_assert = require("audio.bass_assert")
local bass_amplify = require("audio.bass_amplify")
local ffi = require("ffi")
local Sample = require("audio.Sample")
local StreamMemoryTempo = require("audio.StreamMemoryTempo")

local audio = {}

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

audio.newSoundData = function(pointer, size, sample_gain)
	assert(pointer)
	assert(size)
	local sample = bass.BASS_SampleLoad(true, pointer, 0, size, 65535, 0)

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

	if sample_gain and sample_gain > 0 then
		bass_amplify(sample, sample_gain)
	end

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
