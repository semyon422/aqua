local ffi = require("ffi")
local bass = require("audio.bass")
local bass_assert = require("audio.bass_assert")

local info = ffi.new("BASS_SAMPLE")
return function(sample, gain)
	bass_assert(bass.BASS_SampleGetInfo(sample, info) == 1)

	local buffer = ffi.new("int16_t[?]", math.ceil(info.length / 2))
	bass_assert(bass.BASS_SampleGetData(sample, buffer) == 1)

	local amp = math.exp(gain / 20 * math.log(10))
	for i = 0, info.length / 2 - 1 do
		buffer[i] = math.min(math.max(buffer[i] * amp, -32768), 32767)
	end
	bass_assert(bass.BASS_SampleSetData(sample, buffer) == 1)
end
