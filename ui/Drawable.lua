local Node = require("ui.Node")
local bit = require("bit")

---@class ui.TraversalContext
---@field delta_time number
---@field mouse_x number
---@field mouse_y number
---@field mouse_target ui.Node?
---@field focus_requesters ui.Node[]

---@class ui.Pivot
---@field x number
---@field y number

---@alias ui.Color [number, number, number, number]

---@class ui.Drawable : ui.Node
---@operator call: ui.Drawable
---@field children ui.Drawable[]
---@field parent ui.Drawable?
---@field world_transform love.Transform
---@field mouse_over boolean
local Drawable = Node + {}

Drawable.ClassName = "Drawable"

Drawable.Pivot = {
	TopLeft = { x = 0, y = 0 },
	TopCenter = { x = 0.5, y = 0 },
	TopRight = { x = 1, y = 0 },
	CenterLeft = { x = 0, y = 0.5 },
	Center = { x = 0.5, y = 0.5 },
	CenterRight = { x = 1, y = 0.5 },
	BottomLeft = { x = 0, y = 1 },
	BottomCenter = { x = 0.5, y = 1 },
	BottomRight = { x = 1, y = 1 },
}

---@enum ui.SizeMode
Drawable.SizeMode = {
	Fixed = 1,
	Fit = 2,
	Grow = 3,
}

---@enum ui.Arrange
Drawable.Arrange = {
	Absolute = 1,
	FlowH = 2,
	FlowV = 3,
}

---@enum ui.Axis
Drawable.Axis = {
	None = 0,
	X = 1,
	Y = 2,
	Both = 3,
}

local Arrange = Drawable.Arrange
local SizeMode = Drawable.SizeMode
local Axis = Drawable.Axis

---@param params {[string]: any}
function Drawable:new(params)
	self.x = 0
	self.y = 0
	self.angle = 0
	self.scale_x = 1
	self.scale_y = 1
	self.origin = Drawable.Pivot.TopLeft
	self.anchor = Drawable.Pivot.TopLeft
	self.width = 0
	self.height = 0
	self.width_mode = self.SizeMode.Fixed
	self.height_mode = self.SizeMode.Fixed
	self.color = { 1, 1, 1, 1 }
	self.alpha = 1
	self.padding_left = 0
	self.padding_right = 0
	self.padding_top = 0
	self.padding_bottom = 0
	self.child_gap = 0
	self.arrange = self.Arrange.Absolute
	self.world_transform = love.math.newTransform()
	self.mouse_over = false
	self.invalidate_axis = Drawable.Axis.None
	self.handles_mouse_input = false
	self.handles_keyboard_input = false

	Node.new(self, params)

	if #self.color < 4 then
		local missing = 4 - #self.color
		for _ = 1, missing do
			table.insert(self.color, 1)
		end
	end
end

---@generic T : ui.Drawable
---@param drawable T
---@return T
function Drawable:add(drawable)
	Node.add(self, drawable)
	self:propagateLayoutInvalidation(Drawable.Axis.Both)
	return drawable
end

---@param mouse_x number
---@param mouse_y number
---@param imx number
---@param imy number
function Drawable:isMouseOver(mouse_x, mouse_y, imx, imy)
	return imx >= 0 and imx < self.width and imy >= 0 and imy < self.height
end

---@param ctx ui.TraversalContext
function Drawable:updateChildren(ctx)
	for _, child in ipairs(self.children) do
		love.graphics.push()
		child:updateTree(ctx)
		love.graphics.pop()
	end
end

---@param ctx ui.TraversalContext
--- Internal method, don't ever override it.
function Drawable:updateTree(ctx)
	if self.is_disabled then
		return
	end

	if (self.handles_mouse_input or self.handles_keyboard_input) and self.alpha * self.color[4] > 0 then
		if self.handles_keyboard_input then
			table.insert(ctx.focus_requesters, self)
		end

		if not ctx.mouse_target and self.handles_mouse_input then
			local had_focus = self.mouse_over
			local imx, imy = self.world_transform:inverseTransformPoint(ctx.mouse_x, ctx.mouse_y)
			self.mouse_over = self:isMouseOver(ctx.mouse_x, ctx.mouse_y, imx, imy)

			if self.mouse_over then
				ctx.mouse_target = self
			end

			-- TODO: dispatch an event
			if not had_focus and self.mouse_over then
				self:onHover()
			elseif had_focus and not self.mouse_over then
				self:onHoverLost()
			end
		else
			if self.mouse_over then
				self:onHoverLost()
				self.mouse_over = false
			end
		end
	end

	self:update(ctx.delta_time)
	self:updateChildren(ctx)

	if self.invalidate_axis ~= Drawable.Axis.None then
		self:updateLayout()
	end
end

function Drawable:drawChildren()
	for i = #self.children, 1, -1 do
		local child = self.children[i]
		love.graphics.push("all")
		child:drawTree()
		love.graphics.pop()
	end
end

---@private
--- Internal method, don't ever override it.
function Drawable:drawTree()
	if self.is_disabled then
		return
	end

	love.graphics.push("all")
	love.graphics.applyTransform(self.world_transform)
	love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.color[4] * self.alpha)
	self:draw()
	love.graphics.pop()

	self:drawChildren()
end

function Drawable:fitX()
	if self.width_mode == SizeMode.Fixed then
		for _, child in ipairs(self.children) do
			child:fitX()
		end
		return
	end

	local w = 0

	if self.arrange == Arrange.Absolute then
		for _, child in ipairs(self.children) do
			child:fitX()
			w = math.max(w, child.x + child.width)
		end
	elseif self.arrange == Arrange.FlowV then
		for _, child in ipairs(self.children) do
			child:fitX()
			w = math.max(w, child.width)
		end
	elseif self.arrange == Arrange.FlowH then
		for _, child in ipairs(self.children) do
			child:fitX()
			w = w + child.width
		end
		w = w + self.child_gap * (math.max(0, #self.children - 1))
	end

	self.width = self.padding_left + w + self.padding_right
end

function Drawable:fitY()
	if self.height_mode == SizeMode.Fixed then
		for _, child in ipairs(self.children) do
			child:fitY()
		end
		return
	end

	local h = 0

	if self.arrange == Arrange.Absolute then
		for _, child in ipairs(self.children) do
			child:fitY()
			h = math.max(h, child.y + child.height)
		end
	elseif self.arrange == Arrange.FlowH then
		for _, child in ipairs(self.children) do
			child:fitY()
			h = math.max(h, child.height)
		end
	elseif self.arrange == Arrange.FlowV then
		for _, child in ipairs(self.children) do
			child:fitY()
			h = h + child.height
		end
		h = h + (self.child_gap * (math.max(0, #self.children - 1)))
	end

	self.height = self.padding_top + h + self.padding_bottom
end

function Drawable:growX()
	local remaining_width = self.width
	remaining_width = remaining_width - self.padding_left - self.padding_right

	if self.arrange == Arrange.FlowH then
		remaining_width = remaining_width - (self.child_gap * (math.max(0, #self.children - 1)))
	end

	for _, child in ipairs(self.children) do
		if child.width_mode ~= self.SizeMode.Grow then
			remaining_width = remaining_width - child.width
		end
	end

	for _, child in ipairs(self.children) do
		if child.width_mode == self.SizeMode.Grow then
			child.width = remaining_width
		end
		child:growX()
	end
end

function Drawable:growY()
	local remaining_height = self.height
	remaining_height = remaining_height - self.padding_top - self.padding_bottom

	if self.arrange == Arrange.FlowV then
		remaining_height = remaining_height - (self.child_gap * (math.max(0, #self.children - 1)))
	end

	for _, child in ipairs(self.children) do
		if child.height_mode ~= SizeMode.Grow then
			remaining_height = remaining_height - child.height
		end
	end

	for _, child in ipairs(self.children) do
		if child.height_mode == SizeMode.Grow then
			child.height = remaining_height
		end
		child:growY()
	end
end

function Drawable:positionChildren()
	local x, y = 0, 0

	if self.arrange == Arrange.Absolute then
		for _, child in ipairs(self.children) do
			child:updateWorldTransform()
			child:positionChildren()
		end
	elseif self.arrange == Arrange.FlowH then
		for _, child in ipairs(self.children) do
			child:setPosition(x, y)
			child:updateWorldTransform()
			child:positionChildren()
			x = x + child:getWidth() + self.child_gap
		end
	elseif self.arrange == Arrange.FlowV then
		for _, child in ipairs(self.children) do
			child:setPosition(x, y)
			child:updateWorldTransform()
			child:positionChildren()
			y = y + child:getHeight() + self.child_gap
		end
	end
end

function Drawable:updateLayout()
	local axis = self.invalidate_axis

	if bit.band(axis, Axis.X) then
		self:fitX()
		self:growX()
	end
	if bit.band(axis, Axis.Y) then
		self:fitY()
		self:growY()
	end

	if self.parent then
		self.parent:positionChildren()
	else
		self:positionChildren()
	end

	self.invalidate_axis = Axis.None
end

---@param axis ui.Axis
---@return boolean
---@private
--- It's safe to use nodes that have fixed width/height for layout recalculation without going to the root and recalculating the whole thing from scratch
function Drawable:canResolveLayout(axis)
	if bit.band(self.invalidate_axis, axis) ~= 0 then
		return true
	end

	local x_fixed = self.width_mode == SizeMode.Fixed
	local y_fixed = self.height_mode == SizeMode.Fixed

	if bit.band(axis, Axis.X) ~= 0 and not x_fixed then
		return false
	end
	if bit.band(axis, Axis.Y) ~= 0 and not y_fixed then
		return false
	end

	return true
end

---@param axis ui.Axis
--- Finds the suitable node that can handle relayout
function Drawable:propagateLayoutInvalidation(axis)
	if not self.parent then
		self.invalidate_axis = bit.bor(self.invalidate_axis, axis)
		return
	end

	if self.parent:canResolveLayout(axis) then
		self.parent.invalidate_axis = bit.bor(self.parent.invalidate_axis, axis)
	else
		self.parent:propagateLayoutInvalidation(axis)
	end
end

function Drawable:updateWorldTransform()
	local x = self.x + self.anchor.x * self.parent:getLayoutWidth() + self.parent.padding_left
	local y = self.y + self.anchor.y * self.parent:getLayoutHeight() + self.parent.padding_top

	self.world_transform:setTransformation(
		x,
		y,
		self.angle,
		self.scale_x,
		self.scale_y,
		self.origin.x * self:getWidth(),
		self.origin.y * self:getHeight()
	)

	self.world_transform:apply(self.parent.world_transform)
end

---@return number
function Drawable:getX()
	return self.x
end

---@return number
function Drawable:getY()
	return self.y
end

---@return number
function Drawable:getWidth()
	return self.width -- * self.scale_x
end

---@return number
function Drawable:getHeight()
	return self.height -- * self.scale_y
end

---@return number, number
function Drawable:getDimensions()
	return self:getWidth(), self:getHeight()
end

---@return number
function Drawable:getLayoutWidth()
	return self.width - self.padding_left - self.padding_right
end

---@return number
function Drawable:getLayoutHeight()
	return self.height - self.padding_top - self.padding_bottom
end

---@return number, number
function Drawable:getLayoutDimensions()
	return self:getLayoutWidth(), self:getLayoutHeight()
end

---@return number
function Drawable:getAngle()
	return self.angle
end

function Drawable:setBox(x, y, w, h)
	self.x = x
	self.y = y
	self.width = w
	self.height = h
end

---@param x number
function Drawable:setX(x)
	self.x = x
end

---@param y number
function Drawable:setY(y)
	self.y = y
end

---@param x number
---@param y number
function Drawable:setPosition(x, y)
	self.x = x
	self.y = y
end

---@param width number
function Drawable:setWidth(width)
	self.width = width
	self:propagateLayoutInvalidation(Drawable.Axis.X)
end

---@param height number
function Drawable:setHeight(height)
	self.height = height
	self:propagateLayoutInvalidation(Drawable.Axis.Y)
end

function Drawable:setDimensions(width, height)
	self.width = width
	self.height = height
	self:propagateLayoutInvalidation(Drawable.Axis.Both)
end

---@param scale_x number
function Drawable:setScaleX(scale_x)
	self.scale_x = scale_x
end

---@param scale_y number
function Drawable:setScaleY(scale_y)
	self.scale_y = scale_y
end

---@param scale_y number
function Drawable:setScale(scale)
	self.scale_x = scale
	self.scale_y = scale
end

---@param a number
function Drawable:setAngle(a)
	self.angle = a
end

return Drawable
