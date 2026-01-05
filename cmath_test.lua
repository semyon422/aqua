local cmath = require("cmath")
local sqrt = math.sqrt
local exp = math.exp
local pi = math.pi

--[[
	https://en.wikipedia.org/wiki/Inverse_trigonometric_functions
	https://en.wikipedia.org/wiki/Inverse_hyperbolic_functions
]]

local test = {}

---@param t testing.T
function test.all(t)
	local eps = 1e-12
	local function equals(a, b)
		return t:lt(cmath.tocomplex(a - b):abs(), eps)
	end

	t:assert(cmath.iscomplex(1i))
	t:assert(cmath.iscomplex(1 + 1i))
	t:assert(not cmath.iscomplex(1))
	t:eq(tostring(1 + 1i), "1+1i")
	t:eq((1 + 1i) .. (2 + 2i), "1+1i2+2i")
	t:eq((1 + 1i):copy(), 1 + 1i)
	t:eq((1 + 1i):sqrt(), (1 + 1i) ^ 0.5)
	t:eq((0 + 0i) ^ 2, 0 + 0i)
	t:eq((1i):abs(), 1)
	t:eq(#1i, 1)

	equals(-1, 1i * {0, 1})
	equals(-1, {sqrt(2) / 2, sqrt(2) / 2} * (3i * pi / 4):exp())

	t:eq(1i, 1i)
	t:ne(1i, 2i)
	t:eq(1i + 1i, 2i)
	t:eq(1 + 2i, 2i + 1)
	t:eq(1 - 2i, -(2i - 1))
	t:eq(1 - 2i, -(2i - 1))
	t:eq((1 - 2i):conj(), 1 + 2i)

	equals(cmath.tocomplex(-1):sqrt(), 1i)
	equals((1i * pi):exp(), -1)
	equals(1i ^ 1i, exp(-pi / 2))
	equals(cmath.frompolar(1, pi / 2), 1i)

	local r, t = (1 + 1i):polar()
	equals(r, sqrt(2))
	equals(t, pi / 4)

	local z = 1 + 1i
	equals(z, z:sin():asin())
	equals(z, z:cos():acos())
	equals(z, z:tan():atan())
	equals(z, z:cot():acot())
	equals(z, z:sinh():asinh())
	equals(z, z:cosh():acosh())
	equals(z, z:tanh():atanh())
	equals(z, z:coth():acoth())

	local z = 1 - 2i
	equals(z, z:sin():asin())
	equals(z, z:cos():acos())
	equals(z, z:tan():atan())
	equals(z, z:cot():acot())
	equals(-z - pi * 1i, z:sinh():asinh())
	equals(z, z:cosh():acosh(0, 1))
	equals(z + pi * 1i, z:tanh():atanh())
	equals(z + pi * 1i, z:coth():acoth())

	for k1 = -2, 2 do
		for k2 = -2, 2 do
			equals(z, z:sin():asin(k1, k2):sin():asin())
			equals(z, z:cos():acos(k1, k2):cos():acos())
			equals(z, z:tan():atan(k1):tan():atan())
			equals(z, z:cot():acot(k1):cot():acot())
			equals(-z - pi * 1i, z:sinh():asinh(k1, k2):sinh():asinh())
			equals(z, z:cosh():acosh(k1, k2):cosh():acosh(0, 1))
			equals(z + pi * 1i, z:tanh():atanh(k1):tanh():atanh())
			equals(z + pi * 1i, z:coth():acoth(k1):coth():acoth())
		end
	end

	equals((1i):pow(2), -1)

	local z = -1 + 0i
	equals(z:pow(1 / 4, 0), 2 ^ 0.5 / 2 * (1 + 1i))
	equals(z:pow(1 / 4, 1), 2 ^ 0.5 / 2 * (-1 + 1i))
	equals(z:pow(1 / 4, 2), 2 ^ 0.5 / 2 * (-1 - 1i))
	equals(z:pow(1 / 4, 3), 2 ^ 0.5 / 2 * (1 - 1i))
	equals(z:pow(1 / 4, 0):pow(4), z)
	equals(z:pow(1 / 4, 1):pow(4), z)
	equals(z:pow(1 / 4, 2):pow(4), z)
	equals(z:pow(1 / 4, 3):pow(4), z)

	assert(cmath.random():abs() <= 1)
end

return test
