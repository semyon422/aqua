local class = require("class")

---@class ui.Transform
--- Local to this node:
---@field x number
---@field y number
---@field angle number
---@field scale_x number
---@field scale_y number
---@field shear_x number
---@field shear_y number
--- Global to the screen:
---@field transform love.Transform
---@field transform_scale_x number
---@field transform_scale_y number
---@field inverse_transform love.Transform?
--- Managed by a node, should not be changed manually:
---@field layout_x number
---@field layout_y number
---@field origin_x number In pixels
---@field origin_y number In pixels
---@field parent_transform love.Transform?
local Transform = class()

function Transform:new()
	self.x = 0
	self.y = 0
	self.angle = 0
	self.scale_x = 1
	self.scale_y = 1
	self.shear_x = 0
	self.shear_y = 0

	self.transform = love.math.newTransform()
	self.transform_scale_x = 1
	self.transform_scale_y = 1

	self.layout_x = 0
	self.layout_y = 0
	self.origin_x = 0
	self.origin_y = 0

	self.invalidated = false
end

---@param tf love.Transform
---@return number sx
---@return number sy
local function getTransformScale(tf)
	local e1_1, e1_2, _, _, e2_1, e2_2, _, _, e3_1, e3_2 = tf:getMatrix()
	local scale_x = math.sqrt(e1_1 * e1_1 + e2_1 * e2_1 + e3_1 * e3_1)
	local scale_y = math.sqrt(e1_2 * e1_2 + e2_2 * e2_2 + e3_2 * e3_2)
	return scale_x, scale_y
end

local temp_tf = love.math.newTransform()

function Transform:update()
	if self.parent_transform then
		-- The code below doesn't create a new transform, that's good
		-- But it would have been better if there was Transform:apply(other, reverse_order)
		self.transform:reset()
		self.transform:apply(self.parent_transform)
		temp_tf:setTransformation(
			self.layout_x + self.x,
			self.layout_y + self.y,
			self.angle,
			self.scale_x,
			self.scale_y,
			self.origin_x,
			self.origin_y,
			self.shear_x,
			self.shear_y
		)
		self.transform:apply(temp_tf)
	else
		self.transform:setTransformation(
			self.layout_x + self.x,
			self.layout_y + self.y,
			self.angle,
			self.scale_x,
			self.scale_y,
			self.origin_x,
			self.origin_y,
			self.shear_x,
			self.shear_y
		)
	end

	self.transform_scale_x, self.transform_scale_y = getTransformScale(self.transform)
	self.inverse_transform = nil
	self.invalidated = false
end

---@return love.Transform
function Transform:get()
	return self.transform
end

---@return love.Transform
function Transform:getInverse()
	if self.inverse_transform then
		return self.inverse_transform
	end

	self.inverse_transform = self.transform:inverse()
	return self.inverse_transform
end

---@param x number
---@param y number
function Transform:setPosition(x, y)
	self.x, self.y = x, y
	self.invalidated = true
end

---@param x number
---@param y number
function Transform:setScale(x, y)
	self.scale_x, self.scale_y = x, y
	self.invalidated = true
end

---@param x number
---@param y number
function Transform:setShear(x, y)
	self.shear_x, self.shear_y = x, y
	self.invalidated = true
end

---@param a number
function Transform:setAngle(a)
	self.angle = a
	self.invalidated = true
end

---@param x number
---@param y number
---@param angle number
---@param scale_x number
---@param scale_y number
---@param shear_x number
---@param shear_y number
function Transform:setEverything(x, y, angle, scale_x, scale_y, shear_x, shear_y)
	self.x = x
	self.y = y
	self.angle = angle
	self.scale_x = scale_x
	self.scale_y = scale_y
	self.shear_x = shear_x
	self.shear_y = shear_y
end

return Transform
