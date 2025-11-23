local class = require("class")
local ffi = require("ffi")
local byte = require("byte")
local buffer = require("string.buffer")

-- https://audiocoding.cc/articles/2008-05-22-wav-file-structure/

---@class audio.Wave
---@operator call: audio.Wave
local Wave = class()

Wave.bytes_per_sample = 2

function Wave:new()
	self.samples_count = 0 -- number of samples per channel
	self.channels_count = 0
	self.sample_rate = 44100
end

---@param channels_count integer?
---@param samples_count integer?
function Wave:initBuffer(channels_count, samples_count)
	self.channels_count = channels_count or self.channels_count
	self.samples_count = samples_count or self.samples_count

	assert(self.channels_count > 0)
	assert(self.samples_count > 0)

	---@type {[integer]: integer}
	self.data_buf = ffi.new("int16_t[?]", self.samples_count * self.channels_count)
	self.byte_ptr = ffi.cast("uint8_t*", self.data_buf)
end

---@param i integer starting at 0
---@param channel integer starting at 1
---@param sample integer 16 bit [-32768, 32767]
function Wave:setSampleInt(i, channel, sample)
	local j = i * self.channels_count + channel - 1
	assert(j >= 0 and j < self.samples_count * self.channels_count)
	self.data_buf[j] = math.min(math.max(sample, -32768), 32767)
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
	local j = i * self.channels_count + channel - 1
	assert(j >= 0 and j < self.samples_count * self.channels_count)
	return self.data_buf[j]
end

---@param i integer starting at 0
---@param channel integer starting at 1
---@return integer sample
function Wave:getSampleFloat(i, channel)
	return (self:getSampleInt(i, channel) + 32768) / 65535 * 2 - 1
end

function Wave:getDataSize()
	return self.samples_count * self.channels_count * self.bytes_per_sample
end

---@param bytes integer
---@return integer
function Wave:floorBytes(bytes)
	local mul = self.channels_count * self.bytes_per_sample
	return math.floor(bytes / mul) * mul
end

---@param pos integer
---@return number
function Wave:bytesToSeconds(pos)
	return pos / (self.sample_rate * self.channels_count * self.bytes_per_sample)
end

---@param pos number
---@return integer
function Wave:secondsToBytes(pos)
	return math.floor(pos * self.sample_rate) * self.channels_count * self.bytes_per_sample
end

---@return number
function Wave:getDuration()
	return self.samples_count / self.sample_rate
end

function Wave:encode()
	local data_size = self:getDataSize()

	local header_buf = byte.buffer(44)

	header_buf:fill("RIFF") -- chunkId
	header_buf:write("i32", 44 - 8 + data_size) -- chunkSize
	header_buf:fill("WAVE") -- format
	header_buf:fill("fmt ") -- subchunk1Id
	header_buf:write("i32", 16) -- subchunk1Size - 16 for PCM
	header_buf:write("i16", 1) -- audioFormat - no compression
	header_buf:write("i16", self.channels_count) -- numChannels
	header_buf:write("i32", self.sample_rate)
	header_buf:write("i32", self.sample_rate * self.channels_count * self.bytes_per_sample) -- byteRate
	header_buf:write("i16", self.channels_count * self.bytes_per_sample) -- blockAlign
	header_buf:write("i16", self.bytes_per_sample * 8)
	header_buf:fill("data") -- subchunk2ID
	header_buf:write("i32", data_size) -- Subchunk2Size

	assert(header_buf.offset == 44)

	local out_buf = buffer.new(44 + data_size)
	out_buf:putcdata(header_buf.ptr, 44)
	out_buf:putcdata(self.data_buf, data_size)

	return out_buf:tostring()
end

---@param data string
function Wave:decode(data)
	local buf = byte.buffer(#data)
	buf:fill(data):seek(0)

	assert(buf:string(4) == "RIFF")

	local data_size = buf:read("i32")
	assert(data_size == #data - 8)

	assert(buf:string(4) == "WAVE")
	assert(buf:string(4) == "fmt ")

	local subchunk1Size = buf:read("i32")
	assert(subchunk1Size == 16)

	local audioFormat = buf:read("i16")
	assert(audioFormat == 1)

	self.channels_count = buf:read("i16")
	self.sample_rate = buf:read("i32")
	buf:read("i32")
	buf:read("i16")
	self.bytes_per_sample = buf:read("i16") / 8
	assert(self.bytes_per_sample == 2)

	assert(buf:string(4) == "data")

	data_size = buf:read("i32")

	self.samples_count = 1 / self.bytes_per_sample * data_size / self.channels_count

	---@type {[integer]: integer}
	self.data_buf = ffi.new("int16_t[?]", self.samples_count * self.channels_count)

	ffi.copy(self.data_buf, buf:cur(), data_size)
end

return Wave
