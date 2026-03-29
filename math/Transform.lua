local class = require("class")

---@class math.Transform
---@operator call: math.Transform
---@field a number
---@field b number
---@field c number
---@field d number
---@field tx number
---@field ty number
local Transform = class()

function Transform:new()
	self:reset()
end

function Transform:reset()
	self.a = 1
	self.b = 0
	self.c = 0
	self.d = 1
	self.tx = 0
	self.ty = 0
end

---@param x number
---@param y number
---@param angle number?
---@param sx number?
---@param sy number?
---@param ox number?
---@param oy number?
function Transform:setTransformation(x, y, angle, sx, sy, ox, oy)
	local _angle = angle or 0
	local _sx = sx or 1
	local _sy = sy or _sx
	local _ox = ox or 0
	local _oy = oy or 0
	local cosv = math.cos(_angle)
	local sinv = math.sin(_angle)
	local a = cosv * _sx
	local b = sinv * _sx
	local c = -sinv * _sy
	local d = cosv * _sy
	self.a = a
	self.b = b
	self.c = c
	self.d = d
	self.tx = x - _ox * a - _oy * c
	self.ty = y - _ox * b - _oy * d
end

---@param other math.Transform|love.Transform
function Transform:apply(other)
	local a1, b1, c1, d1, tx1, ty1 = self.a, self.b, self.c, self.d, self.tx, self.ty
	local a2, b2, c2, d2, tx2, ty2 = other.a, other.b, other.c, other.d, other.tx, other.ty
	self.a = a1 * a2 + c1 * b2
	self.b = b1 * a2 + d1 * b2
	self.c = a1 * c2 + c1 * d2
	self.d = b1 * c2 + d1 * d2
	self.tx = a1 * tx2 + c1 * ty2 + tx1
	self.ty = b1 * tx2 + d1 * ty2 + ty1
end

---@param x number
---@param y number
---@return number
---@return number
function Transform:transformPoint(x, y)
	return self.a * x + self.c * y + self.tx, self.b * x + self.d * y + self.ty
end

---@param x number
---@param y number
---@return number
---@return number
function Transform:inverseTransformPoint(x, y)
	local det = self.a * self.d - self.b * self.c
	local dx = x - self.tx
	local dy = y - self.ty
	return (self.d * dx - self.c * dy) / det, (-self.b * dx + self.a * dy) / det
end

return Transform
