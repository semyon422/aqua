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

local soundData, sampleRate, sampleCount
local samples
local frames
local sb_cached

local input_complex = ffi.new("complex[?]", size)

local function load_samples()
	samples = ffi.new("complex[?]", sampleCount)
	for i = 0, sampleCount - 1 do
		samples[i] = cmath.tocomplex(soundData:getSample(i, 1))
	end
end

local function window(n)
	return 0.5 * (1 - math.cos(2 * math.pi * n))
end

local plan

local function transform()
	plan = plan or fftw.new(size)
	frames = {}
	for offset = 0, sampleCount - size, hop do
		ffi.copy(input_complex, samples + offset, size * complex_size)
		for i = 0, size - 1 do
			input_complex[i] = input_complex[i] * window(i / (size - 1))
		end

		ffi.copy(plan.buffer_in, input_complex, size * complex_size)
		plan:execute()

		local spectre = ffi.new("complex[?]", size)
		table.insert(frames, spectre)

		ffi.copy(spectre, plan.buffer_out, size * complex_size)
	end
end

local function sf_X(n, k)
	local spectre = frames[n]
	return spectre and spectre[k] or 0i
end

local function sf_H(x)
	return (x + math.abs(x)) / 2
end

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

local function median_average(D, n, a, b, c)
	local sum = 0
	local sum2 = 0
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
local function treshold(n)
	local m, a, a2, avg_min, avg2_min, values = median_average(sf, n, -10, 2, -6)

	return m + alpha * a
	-- return 0
end

local function get_energy(n)
	local frame = frames[n]
	local sum = 0
	for i = 0, size - 1 do
		sum = sum + frame[i]:abs2()
	end
	return sum / size
end

local Onset_mt = {}

function Onset_mt.__eq(a, b) return a.time == b.time end
function Onset_mt.__lt(a, b) return a.time <= b.time end

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

local function process()
	local res = {}

	for i = 1, #frames do
		local e_db = 10 * math.log(get_energy(i) / size, 10)
		if e_db < -70 then
			res[i] = 0
		else
			res[i] = sf(i) - treshold(i)
		end
	end

	local onsets = {}

	local w = 2
	for i = 1 + w, #frames - w do
		local peak, peak_size = get_peak(res, i, w)
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

function ncbt.onsets(sd)
	soundData = sd
	sampleRate = sd:getSampleRate()
	sampleCount = sd:getSampleCount()

	sb_cached = {}

	load_samples()
	transform()
	return process()
end

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

function ncbt.tempo_offset(onsets)
	local out = {}

	local maxOnsets = {}
	for _, onset in ipairs(onsets) do
		if onset.peak_time then
			table.insert(maxOnsets, onset)
		end
	end

	local onsetsDeltas = {}
	for j = 1, 4 do
		for i = 1 + j, #maxOnsets do
			table.insert(onsetsDeltas, maxOnsets[i].peak_time - maxOnsets[i - j].peak_time)
		end
	end
	table.sort(onsetsDeltas)

	local precision = 1000
	local onsetDist = {}
	local dt
	local max_sum = 0
	for i = 1, #onsetsDeltas do
		local floored_dt = math.floor(onsetsDeltas[i] * precision) / precision
		if dt ~= floored_dt then
			dt = floored_dt
			onsetDist[#onsetDist + 1] = {
				t = dt + 1 / precision / 2,
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
	local peaks = {}
	local max_peak
	local max_peak_size = 0
	for i = 1 + w, #onsetDist - w do
		local peak, size = get_delta_peak(onsetDist, i, w)
		if peak and size > 0.5 then
			table.insert(peaks, peak)
			print("peak", peak, size)
			if size > max_peak_size then
				max_peak_size = size
				max_peak = peak
			end
		end
	end

	print("max peak", max_peak)

	------------------------------------

	local max_bin = 0
	local max_bin_index = 0
	local max_bin_tempo = 0
	local max_bin_bins = {}

	local bins_count = 200
	local function find_best(tempo, win, s)
		for j = math.floor(tempo) - win, math.ceil(tempo) + win, s do
			local interval = 60 / j
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

	print("max / avg", max_bin / bin_avg)
	print("tempo", max_bin_tempo)

	out.tempo = max_bin_tempo

	for i = 0, bins_count - 1 do
		max_bin_bins[i] = max_bin_bins[i] / max_bin
	end

	out.bins = max_bin_bins
	out.binsSize = bins_count

	------------------------------------

	local offset = max_bin_index / bins_count * 60 / tempo
	print("offset", offset)

	out.offset = offset

	return out
end

return ncbt
