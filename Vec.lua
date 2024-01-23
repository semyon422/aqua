local class = require("class")

---@class util.Vec
---@operator call: util.Vec
---@operator unm: util.Vec
---@operator add: util.Vec
---@operator sub: util.Vec
---@operator mul: util.Vec
---@operator div: util.Vec
---@operator concat: string
local Vec = class()

---@return number
function Vec:abs2()
	local sum = 0
	for i = 1, #self do
		sum = sum + self[i] ^ 2
	end
	return sum
end

---@return number
function Vec:abs()
	return math.sqrt(self:abs2())
end

---@return util.Vec
function Vec:copy()
	local c = {}
	for i = 1, #self do
		c[i] = self[i]
	end
	return Vec(c)
end

---@return util.Vec
function Vec:norm()
	local r = self:abs()
	if r ~= 0 then
		return self / r
	end
	local c = {}
	for i = 1, #self do
		c[i] = 0
	end
	return Vec(c)
end

---@return util.Vec
function Vec:floor()
	local c = {}
	for i = 1, #self do
		c[i] = math.floor(self[i])
	end
	return Vec(c)
end

---@param a util.Vec
---@param b util.Vec
---@return boolean
function Vec.__eq(a, b)
	return (a - b):abs() < 1e-12
end

---@param a util.Vec
---@return util.Vec
function Vec.__unm(a)
	local c = {}
	for i = 1, #a do
		c[i] = -a[i]
	end
	return Vec(c)
end

---@param a util.Vec
---@param b util.Vec
---@return util.Vec
function Vec.__add(a, b)
	local c = {}
	for i = 1, #a do
		c[i] = a[i] + b[i]
	end
	return Vec(c)
end

---@param a util.Vec
---@param b util.Vec
---@return util.Vec
function Vec.__sub(a, b)
	local c = {}
	for i = 1, #a do
		c[i] = a[i] - b[i]
	end
	return Vec(c)
end

---@param a util.Vec
---@param b util.Vec
---@return util.Vec
function Vec.__mul(a, b)
	local c = {}
	for i = 1, #a do
		c[i] = a[i] * b
	end
	return Vec(c)
end

---@param a util.Vec
---@param b util.Vec
---@return util.Vec
function Vec.__div(a, b)
	local c = {}
	for i = 1, #a do
		c[i] = a[i] / b
	end
	return Vec(c)
end

function Vec.__mod()
	return error("not implemented")
end

function Vec.__lt()
	return error("not implemented")
end

function Vec.__le()
	return error("not implemented")
end

---@param a util.Vec
---@param b util.Vec
---@return string
function Vec.__concat(a, b)
	return tostring(a) .. tostring(b)
end

---@param a util.Vec
---@return string
function Vec.__tostring(a)
	return ("{%s}"):format(table.concat(a, ", "))
end

return Vec
