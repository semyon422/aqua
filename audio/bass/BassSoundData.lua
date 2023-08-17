local SoundData = require("audio.SoundData")
local ffi = require("ffi")
local bit = require("bit")
local bass = require("bass")
local bass_assert = require("bass.assert")

---@class audio.bass.BassSoundData: audio.SoundData
---@operator call:audio.bass.BassSoundData
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

---@param pointer ffi.cdata*
---@param size number
---@return nil?
---@return string?
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

	self.byteData = love.data.newByteData(info.length)
	bass_assert(bass.BASS_SampleGetData(sample, self.byteData:getFFIPointer()) == 1)
end

---@param gain number
function BassSoundData:amplify(gain)
	local sample = self.sample
	local info = self.info

	local buffer = ffi.cast("int16_t*", self.byteData:getFFIPointer())

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

---@return number
function BassSoundData:getBitDepth()
	local flags = self.info.flags
	local bits = 16
	if bit.band(flags, 1) ~= 0 then  -- BASS_SAMPLE_8BITS
		bits = 8
	elseif bit.band(flags, 256) ~= 0 then  -- BASS_SAMPLE_FLOAT
		bits = 32
	end
	return bits
end

---@return number
function BassSoundData:getChannelCount()
	return self.info.chans
end

---@return number
function BassSoundData:getDuration()
	return self:getSampleCount() / self:getSampleRate()
end

---@param i number
---@param channel number?
---@return number
function BassSoundData:getSample(i, channel)
	local buffer = ffi.cast("int16_t*", self.byteData:getFFIPointer())
	if not channel then
		return buffer[i] / 32768
	end
	return buffer[i * self:getChannelCount() + channel - 1] / 32768
end

---@return number
function BassSoundData:getSampleCount()
	local info = self.info
	return info.length / info.chans / (self:getBitDepth() / 8)
end

---@return number
function BassSoundData:getSampleRate()
	return self.info.freq
end

return BassSoundData
