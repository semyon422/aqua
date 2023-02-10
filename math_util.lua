local ceil = math.ceil
local floor = math.floor
local abs = math.abs

local math = {}

function math.round(x, to)
	to = to or 1
	return ((x / to) % 1 < 0.5 and floor(x / to) or ceil(x / to)) * to
end

function math.sign(x)
	return x == 0 and 0 or x / abs(x)
end

function math.belong(x, a, b)
	if b < a then
		a, b = b, a
	end
	return a <= x and x <= b
end

function math.map(x, a, b, c, d)
	return (x - a) * (d - c) / (b - a) + c
end

return math
