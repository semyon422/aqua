local Wave = require("audio.Wave")

local test = {}

---@param t testing.T
function test.basic(t)
	local wave = Wave()

	-- wave:initBuffer(2, wave.sample_rate)
	-- for i = 0, wave.sample_rate - 1 do
	-- 	wave:setSample(i, 1, math.sin(i / wave.sample_rate * 1000) * 32767)
	-- 	wave:setSample(i, 2, math.sin(i / wave.sample_rate * 2000) * 32767)
	-- end
	-- local content = wave:export()

	-- local f = assert(io.open("out.wav", "wb"))
	-- f:write(content)
	-- f:close()

end

return test
