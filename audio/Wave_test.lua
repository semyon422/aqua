local Wave = require("audio.Wave")

local test = {}

---@param t testing.T
function test.basic(t)
	local wave = Wave()

	local samples_count = wave.sample_rate / 10

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
end

return test
