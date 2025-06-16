local Node = require("ui.Node")

---@class ui.UpdateContext
---@field delta_time number
---@field mouse_x number
---@field mouse_y number
---@field mouse_focus boolean

---@class ui.Pivot
---@field x number
---@field y number

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
---@field color number[]
---@field alpha number
---@field accepts_input boolean

---@class ui.Drawable : ui.Node, ui.Drawable.Params
---@operator call: ui.Drawable
---@field children ui.Drawable[]
---@field parent ui.Drawable?
---@field transform love.Transform
---@field mouse_over boolean
local Drawable = Node + {}

Drawable.Pivot = {
	TopLeft = {x = 0, y = 0},
	TopCenter = {x = 0.5, y = 0},
	TopRight = {x = 1, y = 0},
	CenterLeft = {x = 0, y = 0.5},
	Center = {x = 0.5, y = 0.5},
	CenterRight = {x = 1, y = 0.5},
	BottomLeft = {x = 0, y = 1},
	BottomCenter = {x = 0.5, y = 1},
	BottomRight = {x = 1, y = 1}
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
	self.color = self.color or {1, 1, 1, 1}
	self.alpha = self.alpha or 1

	if #self.color < 4 then
		local missing = 4 - #self.color
		for _ = 1, missing do
			table.insert(self.color, 1)
		end
	end

	self.transform = love.math.newTransform()
	self.mouse_over = false
	self.accepts_input = self.accepts_input == nil and false or self.accepts_input
end

---@generic T : ui.Drawable
---@param drawable T
---@return T
function Drawable:add(drawable)
	Node.add(self, drawable)
	---@cast drawable ui.Drawable
	drawable:updateTransform()
	return drawable
end

function Drawable:onHover() end
function Drawable:onHoverLost() end

---@param dt number
function Drawable:update(dt) end
function Drawable:draw() end

---@param mouse_x number
---@param mouse_y number
function Drawable:isMouseOver(mouse_x, mouse_y)
	local imx, imy = love.graphics.inverseTransformPoint(mouse_x, mouse_y)
	return imx >= 0 and imx < self.width and imy >= 0 and imy < self.height
end

---@param ctx ui.UpdateContext
function Drawable:updateTree(ctx)
	if self.is_disabled then
		return
	end

	love.graphics.applyTransform(self.transform)

	if self.accepts_input and ctx.mouse_focus and self.alpha * self.color[4] > 0 then
		local had_focus = self.mouse_over
		self.mouse_over = self:isMouseOver(ctx.mouse_x, ctx.mouse_y)

		if self.mouse_over then
			ctx.mouse_focus = false
		end

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

	for _, child in ipairs(self.children) do
		love.graphics.push()
		child:updateTree(ctx)
		love.graphics.pop()
	end
end

function Drawable:drawTree()
	if self.is_disabled then
		return
	end

	love.graphics.applyTransform(self.transform)

	love.graphics.push("all")
	love.graphics.setColor(self.color)
	self:draw()
	love.graphics.pop()

	for i = #self.children, 1, -1 do
		local child = self.children[i]
		love.graphics.push("all")
		child:drawTree()
		love.graphics.pop()
	end
end

function Drawable:autoSize()
	local w, h = 0, 0
	for _, child in pairs(self.children) do
		w = math.max(w, child.x + child:getWidth())
		h = math.max(h, child.y + child:getHeight())
	end
	self:setWidth(w)
	self:setHeight(h)
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

function Drawable:updateTransform()
	local ox = self.origin.x * self.width
	local oy = self.origin.y * self.height
	local ax = self.anchor.x * self.parent:getWidth()
	local ay = self.anchor.y * self.parent:getHeight()
	self.transform:setTransformation(self.x + ax, self.y + ay, self.angle, self.scale_x, self.scale_y, ox, oy)
end

---@param x number
function Drawable:setX(x)
	self.x = x
	self:updateTransform()
end

---@param y number
function Drawable:setY(y)
	self.y = y
	self:updateTransform()
end

---@param width number
function Drawable:setWidth(width)
	self.width = width
	self:updateTransform()
	for _, child in ipairs(self.children) do
		child:updateTransform()
	end
end

---@param height number
function Drawable:setHeight(height)
	self.height = height
	self:updateTransform()
	for _, child in ipairs(self.children) do
		child:updateTransform()
	end
end

---@param scale_x number
function Drawable:setScaleX(scale_x)
	self.scale_x = scale_x
	self:updateTransform()
	for _, child in ipairs(self.children) do
		child:updateTransform()
	end
end

---@param scale_y number
function Drawable:setScaleY(scale_y)
	self.scale_y = scale_y
	self:updateTransform()
	for _, child in ipairs(self.children) do
		child:updateTransform()
	end
end

return Drawable
