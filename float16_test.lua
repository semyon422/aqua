local float16 = require("aqua.float16")
local bit = require("bit")

local test = {}

---@param t testing.T
function test.basic_values(t)
	local cases = {
		{val = 1.0, bits = 0x3C00},
		{val = 1.0009765625, bits = 0x3C01},
		{val = 2.0, bits = 0x4000},
		{val = 0.5, bits = 0x3800},
		{val = 65504, bits = 0x7BFF}, -- Max normalized
		{val = -2.0, bits = 0xC000},
	}

	for _, c in ipairs(cases) do
		t:eq(float16.encode(c.val), c.bits, ("encode(%s)"):format(c.val))
		t:eq(float16.decode(c.bits), c.val, ("decode(0x%04X)"):format(c.bits))
	end
end

---@param t testing.T
function test.special_values(t)
	-- Zeros
	t:eq(float16.encode(0), 0x0000)
	t:eq(float16.encode(-0), 0x8000)
	t:eq(float16.decode(0x0000), 0)
	t:eq(float16.decode(0x8000), -0)

	-- Infinity
	t:eq(float16.encode(1 / 0), 0x7C00)
	t:eq(float16.encode(-1 / 0), 0xFC00)
	t:eq(float16.decode(0x7C00), 1 / 0)
	t:eq(float16.decode(0xFC00), -1 / 0)

	-- NaN
	local nan_bits = float16.encode(0 / 0)
	t:eq(bit.band(nan_bits, 0x7C00), 0x7C00) -- Exponent all ones
	t:ne(bit.band(nan_bits, 0x03FF), 0) -- Mantissa non-zero
	local decoded_nan = float16.decode(0x7E00)
	t:assert(decoded_nan ~= decoded_nan, "decode(0x7E00) should be NaN")
end

---@param t testing.T
function test.subnormals(t)
	local cases = {
		{val = 2 ^ -14 * (1 / 1024), bits = 0x0001}, -- Min positive subnormal
		{val = 2 ^ -14 * (1023 / 1024), bits = 0x03FF}, -- Max subnormal
		{val = 6.103515625e-05, bits = 0x0400}, -- Min positive normal (2^-14)
	}

	for _, c in ipairs(cases) do
		t:eq(float16.encode(c.val), c.bits, ("encode(%s)"):format(c.val))
		t:eq(float16.decode(c.bits), c.val, ("decode(0x%04X)"):format(c.bits))
	end
end

---@param t testing.T
function test.rounding_ties_to_even(t)
	-- 1.00048828125 is exactly between 1.0 (mantissa 0) and 1.0009765625 (mantissa 1)
	-- Ties to even: 0 is even, so it rounds to 1.0 (0x3C00)
	t:eq(float16.encode(1.00048828125), 0x3C00, "1.00048828125 should round to 1.0 (even mantissa 0)")

	-- 1.00146484375 is exactly between 1.0009765625 (mantissa 1) and 1.001953125 (mantissa 2)
	-- Ties to even: 2 is even, so it rounds to 1.001953125 (0x3C02)
	t:eq(float16.encode(1.00146484375), 0x3C02, "1.00146484375 should round to 1.001953125 (even mantissa 2)")

	-- Just above/below tie
	t:eq(float16.encode(1.00048828126), 0x3C01)
	t:eq(float16.encode(1.00048828124), 0x3C00)
end

return test
