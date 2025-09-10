local Drawable = require("ui.Drawable")

---@class ui.Viewport.Params
---@field target_height number

---@class ui.Viewport : ui.Drawable, ui.Viewport.Params
---@operator call: ui.Viewport
local Viewport = Drawable + {}

Viewport.ClassName = "Viewport"
Viewport.size_mode = Drawable.SizeMode.Inherit

function Viewport:beforeLoad()
	Drawable.beforeLoad(self)
	self.parent = Drawable()
	self.screen_width = love.graphics.getWidth()
	self.screen_height = love.graphics.getHeight()
	self.virtual_screen_width = self.virtual_screen_width or self.screen_width
	self.virtual_screen_height = self.virtual_screen_height or self.screen_height
	self.requires_canvas_update = true
	self:ensureExist("target_height")
	self:updateWorldTransform()
end

---@return love.Canvas
function Viewport:getCanvas()
	return self.canvas
end

---@return number
function Viewport:getViewportScale()
	return 1 / self.inner_scale
end

---@return ui.Viewport
function Viewport:getViewport()
	return self
end

---@return number width
---@return number height
function Viewport:getVirtualScreenDimensions()
	return self.virtual_screen_width, self.virtual_screen_height
end

---@param w number
---@param h number
function Viewport:setVirtualScreenDimensions(w, h)
	self.virtual_screen_width = w
	self.virtual_screen_height = h
	self.requires_canvas_update = true
	self:updateWorldTransform()
end

function Viewport:updateWorldTransform()
	local scale = self.target_height / self.virtual_screen_height
	self.width = self.virtual_screen_width * scale
	self.height = self.virtual_screen_height * scale
	self.inner_scale = 1 / scale

	local tf = love.math.newTransform(
		self.x + self.anchor.x * self.screen_width,
		self.y + self.anchor.y * self.screen_height,
		self.angle,
		self.inner_scale * self.scale_x,
		self.inner_scale * self.scale_y,
		self.origin.x * self.width,
		self.origin.y * self.height
	)

	self.world_transform = tf
	self.negative = love.math.newTransform()
	self.negative:scale(self.inner_scale, self.inner_scale)
	self.negative = self.negative * self.world_transform:inverse()

	self.canvas_transform = love.math.newTransform(
		self.x + (self.anchor.x * self.screen_width),
		self.y + (self.anchor.y * self.screen_height),
		self.angle,
		1,
		1,
		self.origin.x * self.virtual_screen_width,
		self.origin.y * self.virtual_screen_height
	)

	for _, child in ipairs(self.children) do
		child:updateWorldTransform()
	end

	if self.requires_canvas_update then
		self.canvas = love.graphics.newCanvas(self.virtual_screen_width, self.virtual_screen_height)
		self.requires_canvas_update = false
	end
end

function Viewport:update()
	local ww, wh = love.graphics.getDimensions()
	if ww ~= self.screen_width or wh ~= self.screen_height then
		self.screen_width = ww
		self.screen_height = wh
		if self.size_mode == self.SizeMode.Inherit then
			self.virtual_screen_width = ww
			self.virtual_screen_height = wh
			self.requires_canvas_update = true
		end
		self:updateWorldTransform()
	end
end

function Viewport:drawChildren()
	love.graphics.origin()
	love.graphics.setColor(1, 1, 1)
	love.graphics.setCanvas({ self.canvas, stencil = true })
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.applyTransform(self.negative)

	for i = #self.children, 1, -1 do
		local child = self.children[i]
		love.graphics.push("all")
		child:drawTree()
		love.graphics.pop()
	end

	love.graphics.setCanvas()
	love.graphics.origin()
	love.graphics.applyTransform(self.canvas_transform)
	love.graphics.draw(self.canvas)
end

return Viewport
