local Node = require("ui.Node")

---@class ui.TraversalContext
---@field delta_time number
---@field mouse_x number
---@field mouse_y number
---@field mouse_target ui.Node?

---@class ui.Pivot
---@field x number
---@field y number

---@alias ui.Color [number, number, number, number]

---@class ui.Drawable.Params : ui.Node.Params
---@field id string
---@field x number
---@field y number
---@field angle number
---@field scale_x number
---@field scale_y number
---@field origin ui.Pivot
---@field anchor ui.Pivot
---@field width number
---@field height number
---@field percent_width number? Used for Percent size mode
---@field percent_height number? Used for Percent size mode
---@field color ui.Color
---@field alpha number
---@field accepts_input boolean

---@class ui.Drawable : ui.Node, ui.Drawable.Params
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

Drawable.SizeMode = {
	Fixed = 1, -- Fixed width/height
	Auto = 2, -- Drawable:getContentSize() becomes width and height
	Inherit = 3, -- Takes 100% of parent's width and height
	Percent = 4 -- Takes self.percent_width and self.percent_height of parent's width and height
}

---@param params {[string]: any}
function Drawable:new(params)
	Node.new(self, params)

	self.x = self.x or 0
	self.y = self.y or 0
	self.angle = self.angle or 0
	self.scale_x = self.scale_x or 1
	self.scale_y = self.scale_y or 1
	self.origin = self.origin or Drawable.Pivot.TopLeft
	self.anchor = self.anchor or Drawable.Pivot.TopLeft
	self.width = self.width or 0
	self.height = self.height or 0
	self.color = self.color or { 1, 1, 1, 1 }
	self.alpha = self.alpha or 1
	self.size_mode = self.size_mode or Drawable.SizeMode.Fixed

	if #self.color < 4 then
		local missing = 4 - #self.color
		for _ = 1, missing do
			table.insert(self.color, 1)
		end
	end

	self.world_transform = love.math.newTransform()
	self.mouse_over = false
	self.accepts_input = self.accepts_input == nil and false or self.accepts_input
end

---@generic T : ui.Drawable
---@param drawable T
---@return T
function Drawable:add(drawable)
	Node.add(self, drawable)
	---@cast drawable ui.Drawable

	drawable:updateWorldTransform()

	if self.parent then
		self.parent:invalidateLayout()
	end

	return drawable
end

function Drawable:updateWorldTransform()
	local w, h = self:getNewDimensions()
	if w and h then
		self.width = w
		self.height = h
	end

	local tf = love.math.newTransform(
		self.x + self.anchor.x * self.parent:getWidth(),
		self.y + self.anchor.y * self.parent:getHeight(),
		self.angle,
		self.scale_x,
		self.scale_y,
		self.origin.x * self:getWidth(),
		self.origin.y * self:getHeight()
	)

	self.world_transform = self.parent.world_transform * tf

	for _, child in ipairs(self.children) do
		child:updateWorldTransform()
	end

	self:invalidateLayout()
end

function Drawable:kill()
	Node.kill(self)

	if self.parent then
		self.parent:invalidateLayout()
	end
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

	if not ctx.mouse_target and self.accepts_input and self.alpha * self.color[4] > 0 then
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
		end
		self.mouse_over = false
	end

	self:update(ctx.delta_time)
	self:updateChildren(ctx)
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

---@return number width
---@return number height
function Drawable:getContentSize()
	if #self.children == 0 then
		return 0, 0
	end

	local min_x, min_y = math.huge, math.huge
	local max_x, max_y = -math.huge, -math.huge

	for _, child in pairs(self.children) do
		local left = child.x
		local top = child.y
		local right = child.x + child:getWidth()
		local bottom = child.y + child:getHeight()

		min_x = math.min(min_x, left)
		min_y = math.min(min_y, top)
		max_x = math.max(max_x, right)
		max_y = math.max(max_y, bottom)
	end

	local w = max_x - min_x
	local h = max_y - min_y

	return w, h
end

---@return number
---@return number
function Drawable:measure(available_w, available_h)
	return math.min(self:getWidth(), available_w), math.min(self:getHeight(), available_h)
end

---@return number? width
---@return number? height
function Drawable:getNewDimensions()
	if not self.parent then
		return
	end

	if self.size_mode == Drawable.SizeMode.Auto then
		local cw, ch = self:getContentSize()
		local w, h = self:getDimensions()
		if cw ~= w or ch ~= h then
			return cw, ch
		end
	elseif self.size_mode == Drawable.SizeMode.Inherit then
		local pw, ph = self.parent:getDimensions()
		local w, h = self:getDimensions()
		if pw ~= w or ph ~= h then
			return pw, ph
		end
	elseif self.size_mode == Drawable.SizeMode.Percent then
		local pw, ph = self.parent:getDimensions()
		local w, h = self:getDimensions()
		local sw = self.percent_width and self.percent_width * pw or self.width
		local sh = self.percent_height and self.percent_height * ph or self.height
		if sw ~= w or sh ~= h then
			return sw, sh
		end
	end
end

function Drawable:invalidateLayout() end

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
	return self.width * self.scale_x
end

---@return number
function Drawable:getHeight()
	return self.height * self.scale_y
end

---@return number, number
function Drawable:getDimensions()
	return self:getWidth(), self:getHeight()
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
	self:updateWorldTransform()
end

---@param x number
function Drawable:setX(x)
	self.x = x
	self:updateWorldTransform()
end

---@param y number
function Drawable:setY(y)
	self.y = y
	self:updateWorldTransform()
end

---@param x number
---@param y number
function Drawable:setPosition(x, y)
	self.x = x
	self.y = y
	self:updateWorldTransform()
end

---@param width number
function Drawable:setWidth(width)
	self.width = width
	self:updateWorldTransform()
end

---@param height number
function Drawable:setHeight(height)
	self.height = height
	self:updateWorldTransform()
end

function Drawable:setDimensions(width, height)
	self.width = width
	self.height = height
	self:updateWorldTransform()
end

---@param scale_x number
function Drawable:setScaleX(scale_x)
	self.scale_x = scale_x
	self:updateWorldTransform()
end

---@param scale_y number
function Drawable:setScaleY(scale_y)
	self.scale_y = scale_y
	self:updateWorldTransform()
end

---@param scale_y number
function Drawable:setScale(scale)
	self.scale_x = scale
	self.scale_y = scale
	self:updateWorldTransform()
end

---@param a number
function Drawable:setAngle(a)
	self.angle = a
	self:updateWorldTransform()
end

return Drawable
