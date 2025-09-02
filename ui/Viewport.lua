local Drawable = require("ui.Drawable")

---@class ui.Viewport.Params
---@field target_height number

---@class ui.Viewport : ui.Drawable, ui.Viewport.Params
---@operator call: ui.Viewport
local Viewport = Drawable + {}

function Viewport:new(...)
	Drawable.new(self, ...)
	self:ensureExist("target_height")
	self:createViewport()
	self.resize_time = math.huge
	self.resize_defered = false
end

function Viewport:createViewport()
	self.screen_width, self.screen_height = love.graphics.getDimensions()

	self.inner_scale = 1 / self.target_height * self.screen_height
	self.world_transform = love.math.newTransform(0, 0, 0, self.inner_scale, self.inner_scale)
	local x, y = self.world_transform:inverseTransformPoint(0, 0)
	local xw, yh = self.world_transform:inverseTransformPoint(self.screen_width, self.screen_height)
	self.width, self.height = xw - x, yh - y
	self.resize_defered = false
end

---@param ctx ui.UpdateContext
function Viewport:updateTree(ctx)
	local time = love.timer.getTime()
	if self.resize_defered and time >= self.resize_time then
		self:createViewport()
		self:clearTree()
		self:load()
	end

	local ww, wh = love.graphics.getDimensions()
	if not self.resize_defered and (ww ~= self.screen_width or wh ~= self.screen_height) then
		self.resize_defered = true
		self.resize_time = time + 0.2
	end

	love.graphics.origin()
	Drawable.updateTree(self, ctx)
end

function Viewport:drawTree()
	love.graphics.origin()

	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setColor(1, 1, 1)
	for i = #self.children, 1, -1 do
		local child = self.children[i]
		love.graphics.push("all")
		child:drawTree()
		love.graphics.pop()
	end
end

return Viewport
