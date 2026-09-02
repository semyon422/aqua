--[[
	Onset detection based on:

	Non-causal Beat Tracking
	for Rhythm Games
	Bram van de Wetering
	NHTV Breda University of Applied Sciences
	March 14, 2016

	Real-time temporal segmentation of note objects in music signals
	Paul Brossier, Juan Pablo Bello and Mark D. Plumbley
	Centre for Digital Music, Queen Mary University of London
	Proceedings ICMC 2004
	https://www.researchgate.net/publication/228739104_Real-time_temporal_segmentation_of_note_objects_in_music_signals


	https://www.eecs.qmul.ac.uk/~simond/pub/2006/dafx.pdf
]]

local cmath = require("cmath")
local ffi = require("ffi")
local fftw = require("fftw")
local decibel = require("decibel")

local complex_size = ffi.sizeof("complex")

local size = 2048
local hop = 256
local adjust = 0.029

--[[
	using size = 1024 on Tsuki -Yue- leads to many false-positives
]]

--[[
	220-440 Hz

	size = 8192
	hop = 256

	from peak to first sf > 0 are 8 frames
]]

---@class ncbt.SoundData
---@field sample_rate integer?
---@field samples_count integer?
---@field getSample (fun(self: ncbt.SoundData, index: integer, channel: integer): number)?
---@field getSampleFloat (fun(self: ncbt.SoundData, index: integer, channel: integer): number)?
---@field getSampleRate fun(self: ncbt.SoundData): integer
---@field getSampleCount fun(self: ncbt.SoundData): integer

---@class ncbt.Onset
---@field time number
---@field value number
---@field peak_time number?
---@field peak_size number?

---@class ncbt.DistributionPoint
---@field t number
---@field v number

---@class ncbt.IntervalPeak
---@field interval number
---@field weight number
---@field count integer

---@class ncbt.TempoHypothesis
---@field bpm number
---@field interval number
---@field weight number
---@field phase number

---@class ncbt.RhythmHypotheses
---@field interval_peaks ncbt.IntervalPeak[]
---@field tempo_hypotheses ncbt.TempoHypothesis[]

---@class ncbt.TempoOffset
---@field onsetsDeltaDist ncbt.DistributionPoint[]
---@field tempo number
---@field bins {[integer]: number}
---@field binsSize integer
---@field offset number

---@type ncbt.SoundData
local soundData
---@type integer
local sampleRate
---@type integer
local sampleCount
---@type ffi.cdata*
local samples
---@type ffi.cdata*[]
local frames
---@type {[integer]: number}
local sb_cached

local input_complex = ffi.new("complex[?]", size)

local function load_samples()
	samples = ffi.new("complex[?]", sampleCount)
	local getSample = assert(soundData.getSample or soundData.getSampleFloat)
	for i = 0, sampleCount - 1 do
		---@type complex
		local sample = cmath.tocomplex(getSample(soundData, i, 1))
		-- LuaLS cannot model indexed writes through an FFI complex buffer.
		---@diagnostic disable-next-line: no-unknown
		samples[i] = sample
	end
end

local function window(n)
	return 0.5 * (1 - math.cos(2 * math.pi * n))
end

---@type util.Fftw?
local plan

local function transform()
	plan = plan or fftw.new(size, "forward")
	frames = {}
	for offset = 0, sampleCount - size, hop do
		ffi.copy(input_complex, samples + offset, size * complex_size)
		for i = 0, size - 1 do
			---@type complex
			local value = input_complex[i] * window(i / (size - 1))
			-- LuaLS cannot model indexed writes through an FFI complex buffer.
			---@diagnostic disable-next-line: no-unknown
			input_complex[i] = value
		end

		ffi.copy(plan.buffer_in, input_complex, size * complex_size)
		plan:execute()

		local spectre = ffi.new("complex[?]", size)
		table.insert(frames, spectre)

		ffi.copy(spectre, plan.buffer_out, size * complex_size)
	end
end

---@param n integer
---@param k integer
---@return complex
local function sf_X(n, k)
	local spectre = frames[n]
	return spectre and spectre[k] or 0i
end

---@param x number
---@return number
local function sf_H(x)
	return (x + math.abs(x)) / 2
end

---@param n integer
---@return number
local function sf(n)
	if not frames[n] then
		return 0
	end
	if sb_cached[n] then
		return sb_cached[n]
	end
	local sum = 0
	for k = 0, size - 1 do
		sum = sum + sf_H(sf_X(n, k):abs() - sf_X(n - 1, k):abs())
	end
	sb_cached[n] = sum
	return sum
end

---@param D fun(index: integer): number
---@param n integer
---@param a integer
---@param b integer
---@param c integer
---@return number, number, number, number, number, number[]
local function median_average(D, n, a, b, c)
	local sum = 0
	local sum2 = 0
	---@type number[]
	local values = {}
	local count = b - a + 1
	for i = 1, count do
		local v = D(n + a + i - 1)
		values[i] = v
		sum = sum + v
		sum2 = sum2 + v ^ 2
	end
	if c < 0 then
		c = c + count + 1
	end
	table.sort(values)

	local avg_min = 0
	local avg2_min = 0
	for i = 1, c do
		avg_min = avg_min + values[i]
		avg2_min = avg2_min + values[i] ^ 2
	end
	avg_min = avg_min / c
	avg2_min = math.sqrt(avg2_min / c)

	return values[c], sum / count, math.sqrt(sum2 / count), avg_min, avg2_min, values
end

-- local alpha = 0.1
-- local alpha = 0.3
local alpha = 0.5
---@param n integer
---@return number
local function treshold(n)
	local m, a = median_average(sf, n, -10, 2, -6)

	return m + alpha * a
	-- return 0
end

---@param n integer
---@return number
local function get_energy(n)
	local frame = assert(frames[n])
	local sum = 0
	for i = 0, size - 1 do
		-- LuaLS cannot model complex methods through an FFI buffer index.
		---@diagnostic disable-next-line: no-unknown
		sum = sum + frame[i]:abs2()
	end
	return sum / size
end

local Onset_mt = {}

---@param a ncbt.Onset
---@param b ncbt.Onset
function Onset_mt.__eq(a, b) return a.time == b.time end
---@param a ncbt.Onset
---@param b ncbt.Onset
function Onset_mt.__lt(a, b) return a.time <= b.time end

---@param res {[integer]: number}
---@param i integer
---@param w integer
---@return number?, number?
local function get_peak(res, i, w)
	local sum_n, sum_d = 0, 0
	local max = 0

	for j = i - w, i + w do
		local a = math.max(res[j], 0)
		sum_n = sum_n + j * a
		sum_d = sum_d + a
		max = math.max(max, a)
	end

	if sum_n == 0 or res[i] < max then
		return
	end

	return sum_n / sum_d, sum_d
end

---@return ncbt.Onset[]
local function process()
	---@type {[integer]: number}
	local res = {}

	for i = 1, #frames do
		local e_db = decibel.p_to_lp(get_energy(i), size)
		if e_db < -70 then
			res[i] = 0
		else
			res[i] = sf(i) - treshold(i)
		end
	end

	---@type ncbt.Onset[]
	local onsets = {}

	local w = 2
	for i = 1 + w, #frames - w do
		local peak, peak_size = get_peak(res, i, w)
		---@type ncbt.Onset
		local onset = setmetatable({}, Onset_mt)
		onset.time = (i - 1) * hop / sampleRate + adjust
		onset.value = res[i] / size
		table.insert(onsets, onset)
		if peak then
			onset.peak_time = (peak - 1) * hop / sampleRate + adjust
			onset.peak_size = peak_size
		end
	end

	return onsets
end

local ncbt = {}

---@param value number
---@param center number
---@return number
local function foldTempo(value, center)
	while value > center * math.sqrt(2) do value = value / 2 end
	while value < center / math.sqrt(2) do value = value * 2 end
	return value
end

---Builds local interval and tempo candidates without declaring a metrical interpretation.
---@param onsets ncbt.Onset[]
---@param options? {min_time: number?, max_time: number?, max_neighbor: integer?, precision: number?, center_bpm: number?, limit: integer?}
---@return ncbt.RhythmHypotheses
function ncbt.rhythm_hypotheses(onsets, options)
	options = options or {}
	local min_time = options.min_time or -math.huge
	local max_time = options.max_time or math.huge
	local max_neighbor = options.max_neighbor or 4
	local precision = options.precision or 0.005
	local center_bpm = options.center_bpm or 120
	local limit = options.limit or 8

	---@type ncbt.Onset[]
	local peaks = {}
	for _, onset in ipairs(onsets) do
		local time = onset.peak_time or onset.time
		if time >= min_time and time < max_time and (onset.peak_size or onset.value or 0) > 0 then
			table.insert(peaks, onset)
		end
	end
	table.sort(peaks, function(a, b)
		return (a.peak_time or a.time) < (b.peak_time or b.time)
	end)

	---@type {[integer]: {interval: number, weight: number, count: integer}}
	local buckets = {}
	for neighbor = 1, max_neighbor do
		for index = neighbor + 1, #peaks do
			local current = peaks[index]
			local previous = peaks[index - neighbor]
			local interval = (current.peak_time or current.time) - (previous.peak_time or previous.time)
			if interval > 0 then
				local bucket = math.floor(interval / precision + 0.5)
				local weight = math.sqrt(math.max(current.peak_size or current.value or 0, 0) * math.max(previous.peak_size or previous.value or 0, 0))
				local item = buckets[bucket]
				if not item then
					item = {interval = bucket * precision, weight = 0, count = 0}
					buckets[bucket] = item
				end
				item.weight = item.weight + weight
				item.count = item.count + 1
			end
		end
	end

	---@type ncbt.IntervalPeak[]
	local interval_peaks = {}
	for _, item in pairs(buckets) do table.insert(interval_peaks, item) end
	table.sort(interval_peaks, function(a, b) return a.weight > b.weight end)
	while #interval_peaks > limit do table.remove(interval_peaks) end
	local max_weight = interval_peaks[1] and interval_peaks[1].weight or 0
	if max_weight > 0 then
		for _, item in ipairs(interval_peaks) do item.weight = item.weight / max_weight end
	end

	---@type ncbt.TempoHypothesis[]
	local tempo_hypotheses = {}
	local seen = {}
	for _, item in ipairs(interval_peaks) do
		local bpm = foldTempo(60 / item.interval, center_bpm)
		local key = math.floor(bpm * 10 + 0.5)
		if not seen[key] and peaks[1] then
			seen[key] = true
			local interval = 60 / bpm
			local phase_weight, phase_x, phase_y = 0, 0, 0
			for _, onset in ipairs(peaks) do
				local time = onset.peak_time or onset.time
				local weight = math.max(onset.peak_size or onset.value or 0, 0)
				local angle = time % interval / interval * math.pi * 2
				phase_x = phase_x + math.cos(angle) * weight
				phase_y = phase_y + math.sin(angle) * weight
				phase_weight = phase_weight + weight
			end
			local angle = math.atan2(phase_y, phase_x)
			if angle < 0 then angle = angle + math.pi * 2 end
			table.insert(tempo_hypotheses, {
				bpm = bpm,
				interval = interval,
				weight = item.weight * (phase_weight > 0 and math.sqrt(phase_x ^ 2 + phase_y ^ 2) / phase_weight or 0),
				phase = angle / (math.pi * 2) * interval,
			})
		end
	end
	table.sort(tempo_hypotheses, function(a, b) return a.weight > b.weight end)
	return {interval_peaks = interval_peaks, tempo_hypotheses = tempo_hypotheses}
end

---@param sd ncbt.SoundData
---@return ncbt.Onset[]
function ncbt.onsets(sd)
	soundData = sd
	sampleRate = sd.sample_rate or sd:getSampleRate()
	sampleCount = sd.samples_count or sd:getSampleCount()

	sb_cached = {}

	load_samples()
	transform()
	return process()
end

---@param dist ncbt.DistributionPoint[]
---@param i integer
---@param w integer
---@return number?, number?
local function get_delta_peak(dist, i, w)
	local sum_n, sum_d = 0, 0
	local max = 0

	for j = i - w, i + w do
		local a = dist[j]
		sum_n = sum_n + a.t * a.v
		sum_d = sum_d + a.v
		max = math.max(max, a.v)
	end

	if dist[i].v < max then
		return
	end

	return sum_n / sum_d, sum_d
end

---@param t number
---@param mbpm number
---@return number
local function get_tempo(t, mbpm)
	local bpm = 60 / t
	local a, b = math.floor(mbpm / math.sqrt(2)), math.ceil(mbpm * math.sqrt(2))
	while bpm > b do
		bpm = bpm / 2
	end
	while bpm < a do
		bpm = bpm * 2
	end
	return bpm
end

---@param onsets ncbt.Onset[]
---@return ncbt.TempoOffset
function ncbt.tempo_offset(onsets)
	---@type ncbt.TempoOffset
	local out = {
		onsetsDeltaDist = {},
		tempo = 0,
		bins = {},
		binsSize = 0,
		offset = 0,
	}

	---@type ncbt.Onset[]
	local maxOnsets = {}
	for _, onset in ipairs(onsets) do
		if onset.peak_time then
			table.insert(maxOnsets, onset)
		end
	end

	---@type number[]
	local onsetsDeltas = {}
	for j = 1, 4 do
		for i = 1 + j, #maxOnsets do
			table.insert(onsetsDeltas, maxOnsets[i].peak_time - maxOnsets[i - j].peak_time)
		end
	end
	table.sort(onsetsDeltas)

	local precision = 1000
	---@type ncbt.DistributionPoint[]
	local onsetDist = {}
	---@type number?
	local dt
	local max_sum = 0
	for i = 1, #onsetsDeltas do
		local floored_dt = math.floor(onsetsDeltas[i] * precision) / precision
		if dt ~= floored_dt then
			dt = floored_dt
			onsetDist[#onsetDist + 1] = {
				t = floored_dt + 1 / precision / 2,
				v = 0,
			}
		end
		onsetDist[#onsetDist].v = onsetDist[#onsetDist].v + 1
		max_sum = math.max(max_sum, onsetDist[#onsetDist].v)
	end

	for i = 1, #onsetDist do
		onsetDist[i].v = onsetDist[i].v / max_sum
	end

	out.onsetsDeltaDist = onsetDist

	------------------------------------

	local w = precision / 1000 * 10
	---@type number[]
	local peaks = {}
	---@type number?
	local max_peak
	local max_peak_size = 0
	for i = 1 + w, #onsetDist - w do
		local peak, size = get_delta_peak(onsetDist, i, w)
		if peak and size > 0.5 then
			table.insert(peaks, peak)
			if size > max_peak_size then
				max_peak_size = size
				max_peak = peak
			end
		end
	end

	if not max_peak then
		return out
	end

	------------------------------------

	local max_bin = 0
	local max_bin_index = 0
	local max_bin_tempo = 0
	---@type {[integer]: number}
	local max_bin_bins = {}

	local bins_count = 200
	---@param tempo number
	---@param win number
	---@param s number
	local function find_best(tempo, win, s)
		for j = math.floor(tempo) - win, math.ceil(tempo) + win, s do
			local interval = 60 / j
			---@type {[integer]: number}
			local bins = {}
			for i = 0, bins_count - 1 do
				bins[i] = 0
			end
			for _, onset in ipairs(maxOnsets) do
				local i = math.floor(onset.peak_time % interval / interval * bins_count)
				bins[i] = bins[i] + onset.peak_size
				if bins[i] > max_bin then
					max_bin = bins[i]
					max_bin_index = i
					max_bin_tempo = j
					max_bin_bins = bins
				end
			end
		end
	end

	local tempo = get_tempo(max_peak, 100 * math.sqrt(2))

	find_best(tempo, 1, 0.005)

	local bin_avg = 0
	for i = 0, bins_count - 1 do
		bin_avg = bin_avg + max_bin_bins[i]
	end
	bin_avg = bin_avg / bins_count

	out.tempo = max_bin_tempo

	for i = 0, bins_count - 1 do
		max_bin_bins[i] = max_bin_bins[i] / max_bin
	end

	out.bins = max_bin_bins
	out.binsSize = bins_count

	------------------------------------

	local offset = max_bin_index / bins_count * 60 / tempo
	out.offset = offset

	return out
end

return ncbt
