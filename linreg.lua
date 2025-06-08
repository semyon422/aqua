local function avg(x)
	local s = 0
	for i = 1, #x do
		s = s + x[i]
	end
	return s / #x
end

local function avg2(x)
	local s = 0
	for i = 1, #x do
		s = s + x[i] ^ 2
	end
	return s / #x
end

local function avgp(x, y)
	local s = 0
	for i = 1, #x do
		s = s + x[i] * y[i]
	end
	return s / #x
end

return function(x, y)
	local sxy = avgp(x, y)
	local sx = avg(x)
	local sy = avg(y)
	local sx2 = avg2(x)

	local b = (sxy - sx * sy) / (sx2 - sx ^ 2)
	local a = sy - b * sx

	return a, b -- f(x) = a + b * x
end
