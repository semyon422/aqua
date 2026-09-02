local ncbt = require("ncbt")

local test = {}

---@param time number
---@param strength number
---@return ncbt.Onset
local function onset(time, strength)
	return {time = time, value = strength, peak_time = time, peak_size = strength}
end

---@param t testing.T
function test.builds_local_rhythm_hypotheses(t)
	local onsets = {}
	for index = 0, 15 do
		table.insert(onsets, onset(2 + index * 0.5, index % 4 == 0 and 2 or 1))
	end
	local result = ncbt.rhythm_hypotheses(onsets, {
		min_time = 2,
		max_time = 10,
		center_bpm = 120,
		precision = 0.001,
	})
	t:assert(#result.interval_peaks > 0)
	t:assert(#result.tempo_hypotheses > 0)
	t:assert(math.abs(result.tempo_hypotheses[1].bpm - 120) < 0.01)
	t:assert(result.tempo_hypotheses[1].phase < 0.001)
end

---@param t testing.T
function test.filters_hypotheses_by_range(t)
	local onsets = {
		onset(0, 1), onset(0.5, 1), onset(1, 1),
		onset(10, 1), onset(10.4, 1), onset(10.8, 1), onset(11.2, 1),
	}
	local result = ncbt.rhythm_hypotheses(onsets, {
		min_time = 9,
		max_time = 12,
		precision = 0.001,
		center_bpm = 150,
	})
	t:assert(math.abs(result.tempo_hypotheses[1].bpm - 150) < 0.01)
end

return test
