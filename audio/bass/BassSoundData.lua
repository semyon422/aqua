local SoundData = require("audio.SoundData")
local ffi = require("ffi")
local bit = require("bit")
local bass = require("bass")
local bass_assert = require("bass.assert")

local BassSoundData = SoundData + {}

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

local sample_info = ffi.new("BASS_SAMPLE")

function BassSoundData:new(pointer, size)
	assert(pointer)
	assert(size)
	local sample = bass.BASS_SampleLoad(true, pointer, 0, size, 65535, 0)

	-- bass_assert(sample ~= 0)
	if sample == 0 then
		return nil, "can't load sample"
	end

	self.sample = sample

	bass_assert(bass.BASS_SampleGetInfo(sample, sample_info) == 1)
	local info = {}
	for _, field in ipairs(info_fields) do
		info[field] = sample_info[field]
	end
	self.info = info

	self.bits = 16
	if bit.band(info.flags, 1) ~= 0 then  -- BASS_SAMPLE_8BITS
		self.bits = 8
	elseif bit.band(info.flags, 256) ~= 0 then  -- BASS_SAMPLE_FLOAT
		self.bits = 32
	end

	self.duration = info.length / info.chans / (self.bits / 8) / info.freq
end

function BassSoundData:amplify(gain)
	local sample = self.sample
	local info = self.info

	local buffer = ffi.new("int16_t[?]", math.ceil(info.length / 2))
	bass_assert(bass.BASS_SampleGetData(sample, buffer) == 1)

	local amp = math.exp(gain / 20 * math.log(10))
	for i = 0, info.length / 2 - 1 do
		buffer[i] = math.min(math.max(buffer[i] * amp, -32768), 32767)
	end
	bass_assert(bass.BASS_SampleSetData(sample, buffer) == 1)
end

function BassSoundData:release()
	assert(bass.BASS_SampleGetChannels(self.sample, nil) == 0, "Sample is still used")
	bass_assert(bass.BASS_SampleFree(self.sample) == 1)
end

function BassSoundData:getDuration()
	return self.duration
end

return BassSoundData
