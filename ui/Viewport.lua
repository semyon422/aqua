local Drawable = require("ui.Drawable")

---@class ui.Viewport.Params
---@field target_height number

---@class ui.Viewport : ui.Drawable, ui.Viewport.Params
---@operator call: ui.Viewport
local Viewport = Drawable + {}

function Viewport:load()
	self:createViewport()
	self.resize_time = math.huge
	self.resize_defered = false
end

function Viewport:createViewport()
	self.width, self.height = love.graphics.getDimensions()

	local screen_ratio_half = -16 / 9 / 2
	self.inner_scale = 1 / self.target_height * self.height
	self.inner_transform = love.math.newTransform(0.5 * self.width + screen_ratio_half * self.height, 0, 0,
		self.inner_scale, self.inner_scale)

	local x, y = self.inner_transform:inverseTransformPoint(0, 0)
	local xw, yh = self.inner_transform:inverseTransformPoint(self.width, self.height)
	self.scaled_width, self.scaled_height = xw - x, yh - y
	self.resize_defered = false
end

---@param ctx ui.UpdateContext
function Viewport:updateTree(ctx)
	local time = love.timer.getTime()
	if self.resize_defered and time >= self.resize_time then
		self:createViewport()
		--self.event_handler:dispatchEvent("viewportResized")
	end

	local ww, wh = love.graphics.getDimensions()
	if not self.resize_defered and (ww ~= self.width or wh ~= self.height) then
		self.resize_defered = true
		self.resize_time = time + 0.2
		--self.event_handler:dispatchEvent("windowResized")
	end

	love.graphics.origin()
	love.graphics.applyTransform(self.inner_transform)
	love.graphics.translate(love.graphics.inverseTransformPoint(0, 0))
	Drawable.updateTree(self, ctx)
end

function Viewport:drawTree()
	love.graphics.origin()
	love.graphics.applyTransform(self.inner_transform)
	love.graphics.translate(love.graphics.inverseTransformPoint(0, 0))

	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setColor(1, 1, 1)
	for i = #self.children, 1, -1 do
		local child = self.children[i]
		love.graphics.push("all")
		child:drawTree()
		love.graphics.pop()
	end
end

---@return number
function Viewport:getWidth()
	return self.scaled_width
end

---@return number
function Viewport:getHeight()
	return self.scaled_height
end

return Viewport
