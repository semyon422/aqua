local Wave = require("audio.Wave")

local test = {}

---@param t testing.T
function test.basic(t)
	local wave = Wave()

	local duration = 0.1
	local samples_count = wave.sample_rate * duration

	wave:initBuffer(2, samples_count)
	for i = 0, samples_count - 1 do
		wave:setSampleFloat(i, 1, math.sin(i / samples_count * 1000))
		wave:setSampleFloat(i, 2, math.sin(i / samples_count * 2000))
	end

	local data = wave:encode()

	wave = Wave()
	wave:decode(data)

	for i = 0, samples_count - 1 do
		assert(math.abs(wave:getSampleFloat(i, 1) - math.sin(i / samples_count * 1000)) < 1e-4)
		assert(math.abs(wave:getSampleFloat(i, 2) - math.sin(i / samples_count * 2000)) < 1e-4)
	end

	t:eq(wave:getDuration(), duration)
	t:eq(wave:bytesToSeconds(wave:getDataSize()), duration)
	t:eq(wave:secondsToBytes(duration), wave:getDataSize())
end

---@param t testing.T
function test.encode_header(t)
	local header = Wave.encodeHeader(1, 44100, 1, 4)

	t:eq(#header, 44)
	t:eq(header:sub(1, 4), "RIFF")
	t:eq(header:sub(9, 12), "WAVE")
	t:eq(header:sub(13, 16), "fmt ")
	t:eq(header:sub(37, 40), "data")
end

return test
