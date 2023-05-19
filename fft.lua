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
		local y_k = 0i
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

function fft.fft(pi, po, n, sign, step, o_in, o_out)
	if n == 1 then
		po[o_out] = cmath.tocomplex(pi[o_in])
		return
	end
	local k = n / 2
	fft.fft(pi, po, k, sign, step * 2, o_in, o_out)
	fft.fft(pi, po, k, sign, step * 2, o_in + step, o_out + k)
	local w = sign * 2 * math.pi / n
	for i = o_out, o_out + k - 1 do
		local u = po[i]
		local v = po[i + k] * cmath.frompolar(1, w * i)
		po[i] = u + v
		po[i + k] = u - v
	end
end

function fft.simple(p, size, inv)
	local out = {}
	fft.fft(p, out, size, inv and 1 or -1, 1, 0, 0)
	if inv then
		for i = 0, size - 1 do
			out[i] = out[i] / size
		end
	end
	return out
end

return fft
