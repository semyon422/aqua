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

function fft.dft(x, N, inv)
	local w = (inv and -1 or 1) * 2 * math.pi / N * 1i
	local y = {}
	for k = 0, N - 1 do
		local y_k = 0
		for n = 0, N - 1 do
			y_k = y_k + x[n] * (k * n * w):exp()
		end
		y[k] = y_k
		if inv then
			y[k] = y_k / N
		end
	end
	return y
end

function fft.fft(p, n, out, o_out, o_in, step, inv)
	if n == 1 then
		out[o_out] = p[o_in]
		return
	end
	local k = n / 2
	fft.fft(p, k, out, o_out, o_in, step * 2, inv)
	fft.fft(p, k, out, o_out + k, o_in + step, step * 2, inv)
	local w = (inv and -1 or 1) * 2 * math.pi / n * 1i
	for i = o_out, o_out + k - 1 do
		local u = out[i]
		local v = out[i + k] * (w * i):exp()
		out[i] = u + v
		out[i + k] = u - v
	end
end

function fft.simple(p, size, inv)
	local out = {}
	fft.fft(p, size, out, 0, 0, 1, inv)
	if inv then
		for i = 0, size - 1 do
			out[i] = out[i] / size
		end
	end
	return out
end

return fft
