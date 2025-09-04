local Drawable = require("ui.Drawable")

---@class ui.Viewport.Params
---@field target_height number

---@class ui.Viewport : ui.Drawable, ui.Viewport.Params
---@operator call: ui.Viewport
local Viewport = Drawable + {}

function Viewport:beforeLoad()
	Drawable.beforeLoad(self)
	self:ensureExist("target_height")
	self:createViewport()
end

---@return love.Canvas
function Viewport:getCanvas()
	return self.canvas
end

---@return number
function Viewport:getViewportScale()
	return self.inner_scale
end

---@return ui.Viewport
function Viewport:getViewport()
	return self
end

---@return number width
---@return number height
function Viewport:getScreenDimensions()
	return self.screen_width, self.screen_height
end

function Viewport:updateWorldTransform() end

function Viewport:invalidateLayout() end

function Viewport:createViewport()
	self.screen_width, self.screen_height = love.graphics.getDimensions()

	self.inner_scale = 1 / self.target_height * self.screen_height
	self.world_transform = love.math.newTransform(0, 0, 0, self.inner_scale, self.inner_scale)
	local x, y = self.world_transform:inverseTransformPoint(0, 0)
	local xw, yh = self.world_transform:inverseTransformPoint(self.screen_width, self.screen_height)
	self.width = xw - x
	self.height = yh - y
	self.canvas = love.graphics.newCanvas(self.screen_width, self.screen_height)

	for _, v in ipairs(self.children) do
		v:updateWorldTransform()
	end
end

function Viewport:update(ctx)
	local ww, wh = love.graphics.getDimensions()
	if ww ~= self.screen_width or wh ~= self.screen_height then
		self:createViewport()
	end
end

function Viewport:drawChildren()
	love.graphics.setCanvas({ self.canvas, stencil = true })
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setColor(1, 1, 1)

	for i = #self.children, 1, -1 do
		local child = self.children[i]
		love.graphics.push("all")
		child:drawTree()
		love.graphics.pop()
	end

	love.graphics.setCanvas()
	love.graphics.draw(self.canvas)
end

return Viewport
