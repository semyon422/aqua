local cmath = require("cmath")

local fft = {}

function fft.gen_wave(sample_count, sample_rate, waves)
	local wave = {}
	for i = 0, sample_count - 1 do
		wave[i] = 0
	end
	for _, w in ipairs(waves) do
		local a, f, p = w.a or 1, w.f or 100, w.p or 0
		for i = 0, sample_count - 1 do
			wave[i] = wave[i] + a * math.sin(2 * math.pi * f * i / sample_rate + p)
		end
	end
	return wave
end

-- Hann window
-- https://en.wikipedia.org/wiki/Window_function#Hann_and_Hamming_windows
function fft.window(n)
	return 0.5 * (1 - math.cos(2 * math.pi * n))
end

local pi, po, sign, w, o_in_0, size
local function _fft(n, step, o_in, o_out)
	if n == 1 then
		local s = w and w((o_in - o_in_0) / (size - 1), size) or 1
		po[o_out] = cmath.tocomplex(pi[o_in] * s)
		return
	end
	local k = n / 2
	_fft(k, step * 2, o_in, o_out)
	_fft(k, step * 2, o_in + step, o_out + k)
	local o = sign * 2 * math.pi / n
	for i = o_out, o_out + k - 1 do
		local u = po[i]
		local v = po[i + k] * cmath.frompolar(1, o * i)
		po[i] = u + v
		po[i + k] = u - v
	end
end

function fft.fft(_pi, _po, _sign, n, step, o_in, o_out, _w)
	pi, po, sign = _pi, _po, _sign
	w, o_in_0, size = _w, o_in, n
	_fft(n, step, o_in, o_out)
end

function fft.simple(p, n, inv, windowed)
	local out = {}
	fft.fft(p, out, inv and 1 or -1, n, 1, 0, 0, windowed and fft.window)
	if inv then
		for i = 0, size - 1 do
			out[i] = out[i] / size
		end
	end
	return out
end

return fft
