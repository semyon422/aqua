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
---@field color ui.RGBA
---@field alpha number
---@field blend_colors boolean
---@field accepts_input boolean

---@class ui.Drawable : ui.Node, ui.Drawable.Params
---@operator call: ui.Drawable
---@field children ui.Drawable[]
---@field parent ui.Drawable?
---@field transform love.Transform
---@field mouse_over boolean
local Drawable = Node + {}

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
	self.blend_colors = false

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

	if self.parent then
		self.parent:invalidateLayout()
	end

	return drawable
end

function Drawable:kill()
	Node.kill(self)

	if self.parent then
		self.parent:invalidateLayout()
	end
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

---@param ctx ui.TraversalContext
function Drawable:updateChildren(ctx)
	for _, child in ipairs(self.children) do
		love.graphics.push()
		child:updateTree(ctx)
		love.graphics.pop()
	end
end

---@param ctx ui.TraversalContext
function Drawable:updateTree(ctx)
	if self.is_disabled then
		return
	end

	love.graphics.applyTransform(self.transform)

	if self.accepts_input and self.alpha * self.color[4] > 0 then
		local had_focus = self.mouse_over
		self.mouse_over = self:isMouseOver(ctx.mouse_x, ctx.mouse_y)

		if self.mouse_over then
			ctx.mouse_target = self
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

---@return number
---@return number
---@return number
---@return number
function Drawable:mixColors()
	local r, g, b, a = love.graphics.getColor()
	r = r * self.color[1]
	g = g * self.color[2]
	b = b * self.color[3]
	a = a * self.color[4] * self.alpha
	return r, g, b, a
end

function Drawable:drawTree()
	if self.is_disabled then
		return
	end

	local r, g, b, a = 0, 0, 0, 0

	if self.blend_colors then
		r, g, b, a = self:mixColors()
	else
		r, g, b, a = self.color[1], self.color[2], self.color[3], self.color[4] * self.alpha
	end

	if a <= 0 then
		return
	end

	love.graphics.applyTransform(self.transform)

	love.graphics.setColor(r, g, b, a)
	love.graphics.push("all")
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

function Drawable:autoSize()
	local w, h = self:getContentSize()
	self:setWidth(w)
	self:setHeight(h)
end

---@return number
---@return number
function Drawable:measure(available_w, available_h)
	return math.min(self:getWidth(), available_w), math.min(self:getHeight(), available_h)
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

function Drawable:updateTransform()
	local ox = self.origin.x * self.width
	local oy = self.origin.y * self.height
	local ax = self.anchor.x * self.parent:getWidth()
	local ay = self.anchor.y * self.parent:getHeight()
	self.transform:setTransformation(self.x + ax, self.y + ay, self.angle, self.scale_x, self.scale_y, ox, oy)
end

function Drawable:setBox(x, y, w, h)
	self.x = x
	self.y = y
	self.width = w
	self.height = h
	self:updateTransform()
	for _, child in ipairs(self.children) do
		child:updateTransform()
	end
	self.parent:invalidateLayout()
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
	self.parent:invalidateLayout()
end

---@param height number
function Drawable:setHeight(height)
	self.height = height
	self:updateTransform()
	for _, child in ipairs(self.children) do
		child:updateTransform()
	end
	self.parent:invalidateLayout()
end

---@param scale_x number
function Drawable:setScaleX(scale_x)
	self.scale_x = scale_x
	self:updateTransform()
	for _, child in ipairs(self.children) do
		child:updateTransform()
	end
	self.parent:invalidateLayout()
end

---@param scale_y number
function Drawable:setScaleY(scale_y)
	self.scale_y = scale_y
	self:updateTransform()
	for _, child in ipairs(self.children) do
		child:updateTransform()
	end
	self.parent:invalidateLayout()
end

---@param t {[string]: any}
function Drawable:applyRecurse(t)
	for k, v in pairs(t) do
		self[k] = v
	end

	for _, child in ipairs(self.children) do
		child:applyRecurse(t)
	end
end

local sound_play_time = {}

---@param sound audio.Source
---@param limit number?
function Drawable.playSound(sound, limit)
	if not sound then
		print("no sound")
		return
	end

	limit = limit or 0.05

	local prev_time = sound_play_time[sound] or 0
	local current_time = love.timer.getTime()

	if current_time > prev_time + limit then
		sound:stop()
		sound_play_time[sound] = current_time
	end

	sound:play()
end

return Drawable
