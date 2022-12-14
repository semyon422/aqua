local ffi = require("ffi")

local complex = ffi.typeof(1i)

local function iscomplex(z) return ffi.istype(complex, z) end
local function tocomplex(v) return iscomplex(v) and v or complex(v) end
local function assert_int(x) return assert(x and x % 1 == 0, "k should be integer") and x end

local cmath = {}
local cplex = {}

cmath.complex = complex
cmath.iscomplex = iscomplex
cmath.tocomplex = tocomplex
function cmath.frompolar(r, t) return complex(r * math.cos(t), r * math.sin(t)) end
function cmath.random() return cmath.frompolar(math.random(), math.random() * 2 * math.pi) end

function cplex.exp(z) return complex(math.exp(z[0]) * math.cos(z[1]), math.exp(z[0]) * math.sin(z[1])) end
function cplex.log(z, k) return z == 0 and 0 / 0 or complex(math.log(#z), z:arg() + 2 * math.pi * assert_int(k or 0)) end
function cplex.pow(z, n, k) return z == 0 and n ~= 0 and 0 or (n * z:log(k)):exp() end
function cplex.copy(z) return complex(z[0], z[1]) end
function cplex.abs2(z) return z[0] ^ 2 + z[1] ^ 2 end
function cplex.abs(z) return math.sqrt(cplex.abs2(z)) end
function cplex.arg(z) return math.atan2(z[1], z[0]) end
function cplex.polar(z) return #z, z:arg() end
function cplex.sqrt(z, k) return z:pow(0.5, k) end
function cplex.conj(z) return complex(z[0], -z[1]) end
function cplex.sin(z) return ((1i * z):exp() - (-1i * z):exp()) / 2i end
function cplex.cos(z) return ((1i * z):exp() + (-1i * z):exp()) / 2 end
function cplex.tan(z) return cplex.sin(z) / cplex.cos(z) end
function cplex.cot(z) return cplex.cos(z) / cplex.sin(z) end
function cplex.asin(z, k1, k2) return -1i * (1i * z + (1 - z:pow(2)):pow(0.5, k2)):log(k1) end
function cplex.acos(z, k1, k2) return -1i * (z + 1i * (1 - z:pow(2)):pow(0.5, k2)):log(k1) end
function cplex.atan(z, k) return -1i / 2 * ((1i - z) / (1i + z)):log(k) end
function cplex.acot(z, k) return 1i / 2 * ((z - 1i) / (z + 1i)):log(k) end
function cplex.sinh(z) return (z:exp() - (-z):exp()) / 2 end
function cplex.cosh(z) return (z:exp() + (-z):exp()) / 2 end
function cplex.tanh(z) return cplex.sinh(z) / cplex.cosh(z) end
function cplex.coth(z) return cplex.cosh(z) / cplex.sinh(z) end
function cplex.asinh(z, k1, k2) return 1i * cplex.asin(-1i * z, k1, k2) end
function cplex.acosh(z, k1, k2) return 1i * cplex.acos(z, k1, k2) end
function cplex.atanh(z, k) return 1i * cplex.atan(-1i * z, k) end
function cplex.acoth(z, k) return 1i * cplex.acot(1i * z, k) end

local mt = {}

function mt.__eq(z, c) return z[0] == c[0] and z[1] == c[1] end
function mt.__add(z, c) return complex(z[0] + c[0], z[1] + c[1]) end
function mt.__sub(z, c) return complex(z[0] - c[0], z[1] - c[1]) end
function mt.__mul(z, c) return complex(z[0] * c[0] - z[1] * c[1], z[0] * c[1] + z[1] * c[0]) end
function mt.__div(z, c) return complex((z[0] * c[0] + z[1] * c[1]) / c:abs2(), (z[1] * c[0] - z[0] * c[1]) / c:abs2()) end

for k, v in pairs(mt) do
	mt[k] = function(z, c) return v(tocomplex(z), tocomplex(c)) end
end

function mt.__index(_, key) return cplex[key] end
function mt.__unm(z) return complex(-z[0], -z[1]) end
function mt.__pow(z, c) return tocomplex(z):pow(c) end
function mt.__concat(z, c) return tostring(z) .. tostring(c) end
function mt.__mod() return error("__mod not implemented") end
function mt.__lt() return error("__lt not implemented") end
function mt.__le() return error("__le not implemented") end
mt.__len = cplex.abs

cmath.complex = ffi.metatype(complex, mt)

return cmath
