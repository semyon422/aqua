local bit = require("bit")

-- IEEE 754 half-precision (16-bit) floating point implementation.
local float16 = {}

-- Constants
local POW_2_N24 = 2 ^ 24
local POW_2_24 = 1 / POW_2_N24

-- Pre-calculate exponent table for decoding
---@type {[integer]: integer}
local DECODE_EXP_TABLE = {}
for i = 1, 30 do
	DECODE_EXP_TABLE[i] = 2 ^ (i - 15)
end

---@param x number
---@return number
local function round_ties_to_even(x)
	local i = math.floor(x)
	local f = x - i
	if f > 0.5 then
		return i + 1
	elseif f < 0.5 then
		return i
	end
	-- Tie (f == 0.5)
	return (i % 2 == 0) and i or (i + 1)
end

---Decodes a 16-bit half-precision floating point number.
---@param n number The 16-bit integer representation.
---@return number
function float16.decode(n)
	local sign = bit.rshift(n, 15) == 1 and -1 or 1
	local exp = bit.band(bit.rshift(n, 10), 0x1F)
	local frac = bit.band(n, 0x3FF)

	if exp == 0 then
		if frac == 0 then
			return sign * 0
		end
		-- Subnormal: sign * 2^-14 * (frac / 1024) = sign * frac * 2^-24
		return sign * frac * POW_2_24
	elseif exp == 31 then
		if frac == 0 then
			return sign * (1 / 0) -- Infinity
		end
		return 0 / 0 -- NaN
	end

	-- Normalized: sign * 2^(exp - 15) * (1 + frac / 1024)
	return sign * DECODE_EXP_TABLE[exp] * (1 + frac / 1024)
end

---Encodes a number into a 16-bit half-precision floating point representation.
---@param n number
---@return number The 16-bit integer representation.
function float16.encode(n)
	-- Handle 0 and -0
	if n == 0 then
		-- Check for -0 using 1/n trick
		return (1 / n < 0) and 0x8000 or 0x0000
	end

	local sign = 0
	if n < 0 then
		sign = 0x8000
		n = -n
	end

	-- Handle Inf and NaN
	if n == 1 / 0 then
		return bit.bor(sign, 0x7C00)
	end
	if n ~= n then
		return 0x7E00 -- Standard NaN
	end

	local f, e = math.frexp(n)
	-- n = f * 2^e. Normalize f to [1, 2) -> f' = f*2, e' = e-1
	-- Bias for Float16 is 15. exp = e' + 15 = e + 14.
	local exp = e + 14

	if exp <= 0 then
		-- Subnormal or Underflow
		-- Multiplicating by 2^24 is faster than dividing by 2^-24
		local mantissa = round_ties_to_even(n * POW_2_N24)
		if mantissa >= 1024 then
			-- Rounds up to the smallest normalized number (exp=1, mantissa=0)
			return bit.bor(sign, 0x0400)
		end
		return bit.bor(sign, mantissa)
	elseif exp >= 31 then
		-- Overflow to Infinity
		return bit.bor(sign, 0x7C00)
	end

	-- Normalized
	local mantissa = round_ties_to_even((f * 2 - 1) * 1024)
	if mantissa >= 1024 then
		exp = exp + 1
		mantissa = 0
		if exp >= 31 then
			return bit.bor(sign, 0x7C00)
		end
	end

	return bit.bor(sign, bit.lshift(exp, 10), mantissa)
end

return float16
