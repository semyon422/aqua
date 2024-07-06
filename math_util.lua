local math_util = {}

function math_util.lerp(t, a, b)
	return a * (1 - t) + b * t
end

---@param x number
---@param to number?
---@return number
function math_util.round(x, to)
	to = to or 1
	return ((x / to) % 1 < 0.5 and math.floor(x / to) or math.ceil(x / to)) * to
end

---@param x number
---@return number
function math_util.sign(x)
	if x ~= x then
		return x
	end
	if x == 0 then
		return 0
	end
	return x < 0 and -1 or 1
end

---@param x number
---@param a number
---@param b number
---@return boolean
function math_util.belong(x, a, b)
	if b < a then
		a, b = b, a
	end
	return a <= x and x <= b
end

---@param x number
---@param a number
---@param b number
---@param c number
---@param d number
---@return number
function math_util.map(x, a, b, c, d)
	return (x - a) * (d - c) / (b - a) + c
end

---@param x number
---@param a number
---@param b number
---@return number
function math_util.clamp(x, a, b)
	return math.min(math.max(x, a), b)
end

---@param l table
---@param f function
function math_util.lmap(l, f)
	for i = 1, #l do
		l[i] = f(l[i])
	end
end

---@param list number
---@param weights table
---@return any?
---@return number?
function math_util.weighted_median(list, weights)
	local sum = 0
	for i = 1, #list do
		sum = sum + weights[i]
		if sum >= 0.5 then
			return list[i], i
		end
	end
end

---@param a number
---@param b number
---@param c number
---@param d number
---@return number
local function det(a, b, c, d)
	return a * d - b * c
end

---@param a number
---@param b number
---@param c number
---@param d number
---@return boolean
function math_util.intersect1(a, b, c, d)
	if a > b then a, b = b, a end
	if c > d then c, d = d, c end
	return math.max(a, c) <= math.min(b, d)
end

local between = math_util.belong

-- https://e-maxx.ru/algo/segments_intersection_checking

---@param a_x number
---@param a_y number
---@param b_x number
---@param b_y number
---@param c_x number
---@param c_y number
---@param d_x number
---@param d_y number
---@return boolean
function math_util.intersect(a_x, a_y, b_x, b_y, c_x, c_y, d_x, d_y)
	local A1, B1 = a_y - b_y, b_x - a_x
	local A2, B2 = c_y - d_y, d_x - c_x
	local C1, C2 = -A1 * a_x - B1 * a_y, -A2 * c_x - B2 * c_y
	local zn = det(A1, B1, A2, B2)
	if zn ~= 0 then
		local x = -det(C1, B1, C2, B2) / zn
		local y = -det(A1, C1, A2, C2) / zn
		return between(x, a_x, b_x) and between(y, a_y, b_y) and between(x, c_x, d_x) and between(y, c_y, d_y)
	end

	return det(A1, C1, A2, C2) == 0 and det(B1, C1, B2, C2) == 0
		and math_util.intersect1(a_x, b_x, c_x, d_x)
		and math_util.intersect1(a_y, b_y, c_y, d_y)
end

---@param s table
---@param c table
---@return boolean
function math_util.intersect2(s, c)
	local S, C = #s / 2 - 1, #c / 2 - 1
	for i = 0, S do
		for j = 0, C do
			local n, m = i ~= S and i + 1 or 0, j ~= C and j + 1 or 0
			local a_x, a_y = s[i * 2 + 1], s[i * 2 + 2]
			local b_x, b_y = s[n * 2 + 1], s[n * 2 + 2]
			local c_x, c_y = c[j * 2 + 1], c[j * 2 + 2]
			local d_x, d_y = c[m * 2 + 1], c[m * 2 + 2]
			if math_util.intersect(a_x, a_y, b_x, b_y, c_x, c_y, d_x, d_y) then
				return true
			end
		end
	end
	for i = 0, C do
		if math_util.isPointInsidePolygon(s, c[i * 2 + 1], c[i * 2 + 2]) then
			return true
		end
	end
	for i = 0, S do
		if math_util.isPointInsidePolygon(c, s[i * 2 + 1], s[i * 2 + 2]) then
			return true
		end
	end
	return false
end

-- https://ru.wikibooks.org/wiki/Реализации_алгоритмов/Задача_о_принадлежности_точки_многоугольнику

---@param p table
---@param x number
---@param y number
---@return boolean
function math_util.isPointInsidePolygon(p, x, y)
	local flag = false
	local i1, i2, S, S1, S2, S3
	local N = #p / 2
	for n = 0, N - 1 do
		i1 = n < N - 1 and n + 1 or 0
		while not flag do
			i2 = i1 + 1
			if i2 >= N then
				i2 = 0
			end
			if i2 == (n < N - 1 and n + 1 or 0) then
				break
			end
			S = math.abs(p[i1 * 2 + 1] * (p[i2 * 2 + 2] - p[n * 2 + 2]) +
				p[i2 * 2 + 1] * (p[n * 2 + 2] - p[i1 * 2 + 2]) +
				p[n * 2 + 1] * (p[i1 * 2 + 2] - p[i2 * 2 + 2]))
			S1 = math.abs(p[i1 * 2 + 1] * (p[i2 * 2 + 2] - y) +
				p[i2 * 2 + 1] * (y - p[i1 * 2 + 2]) +
				x * (p[i1 * 2 + 2] - p[i2 * 2 + 2]))
			S2 = math.abs(p[n * 2 + 1] * (p[i2 * 2 + 2] - y) +
				p[i2 * 2 + 1] * (y - p[n * 2 + 2]) +
				x * (p[n * 2 + 2] - p[i2 * 2 + 2]))
			S3 = math.abs(p[i1 * 2 + 1] * (p[n * 2 + 2] - y) +
				p[n * 2 + 1] * (y - p[i1 * 2 + 2]) +
				x * (p[i1 * 2 + 2] - p[n * 2 + 2]))
			if S == S1 + S2 + S3 and S ~= 0 then
				flag = true
				break
			end
			i1 = i1 + 1
			if i1 >= N then
				i1 = 0
				break
			end
		end
		if not flag then
			break
		end
	end
	return flag
end

---https://www.lua.org/pil/9.3.htm
---@param a table
---@param n number
---@param t number
local function permgen(a, n, t)
	if n == 0 then
		coroutine.yield(a, t)
		return
	end
	for i = 1, n do
		a[n], a[i] = a[i], a[n]
		permgen(a, n - 1, i ~= n and t + 1 or t)
		a[n], a[i] = a[i], a[n]
	end
end

---@param a table
---@return function
function math_util.permutations(a)
	return coroutine.wrap(function() permgen(a, #a, 0) end)
end

return math_util
