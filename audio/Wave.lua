local class = require("class")
local ffi = require("ffi")
local byte = require("byte")
local buffer = require("string.buffer")

-- https://audiocoding.cc/articles/2008-05-22-wav-file-structure/

---@class audio.Wave
---@operator call: audio.Wave
local Wave = class()

Wave.bits_per_sample = 16

function Wave:new()
	self.samples_count = 0 -- number of samples per channel
	self.channels_count = 0
	self.sample_rate = 44100
end

---@param channels_count integer
---@param samples_count integer
function Wave:initBuffer(channels_count, samples_count)
	self.channels_count = channels_count
	self.samples_count = samples_count
	---@type {[integer]: integer}
	self.data_buf = ffi.new("int16_t[?]", self.samples_count * self.channels_count)
end

---@param i integer starting at 0
---@param channel integer starting at 1
---@param sample integer 16 bit [-32768, 32767]
function Wave:setSampleInt(i, channel, sample)
	self.data_buf[i * self.channels_count + channel - 1] = math.min(math.max(sample, -32768), 32767)
end

---@param i integer starting at 0
---@param channel integer starting at 1
---@param sample number
function Wave:setSampleFloat(i, channel, sample)
	self:setSampleInt(i, channel, math.floor((sample + 1) / 2 * 65535 - 32768))
end

---@param i integer starting at 0
---@param channel integer starting at 1
---@return integer sample 16 bit [-32768, 32767]
function Wave:getSampleInt(i, channel)
	return self.data_buf[i * self.channels_count + channel - 1]
end

---@param i integer starting at 0
---@param channel integer starting at 1
---@return integer sample
function Wave:getSampleFloat(i, channel)
	return (self:getSampleInt(i, channel) + 32768) / 65535 * 2 - 1
end

function Wave:getDataSize()
	return self.samples_count * self.channels_count * self.bits_per_sample / 8
end

function Wave:export()
	local data_size = self:getDataSize()

	local header_buf = byte.buffer(44)

	header_buf:fill("RIFF") -- chunkId
	header_buf:int32_le(44 - 8 + data_size) -- chunkSize
	header_buf:fill("WAVE") -- format
	header_buf:fill("fmt ") -- subchunk1Id
	header_buf:int32_le(16) -- subchunk1Size - 16 for PCM
	header_buf:int16_le(1) -- audioFormat - no compression
	header_buf:int16_le(self.channels_count) -- numChannels
	header_buf:int32_le(self.sample_rate)
	header_buf:int32_le(self.sample_rate * self.channels_count * self.bits_per_sample / 8) -- byteRate
	header_buf:int16_le(self.channels_count * self.bits_per_sample / 8) -- blockAlign
	header_buf:int16_le(self.bits_per_sample)
	header_buf:fill("data") -- subchunk2ID
	header_buf:int32_le(data_size) -- Subchunk2Size

	assert(header_buf.offset == 44)

	local out_buf = buffer.new(44 + data_size)
	out_buf:putcdata(header_buf.pointer, 44)
	out_buf:putcdata(self.data_buf, data_size)

	return out_buf:tostring()
end

return Wave
