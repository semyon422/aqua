local Drawable = require("ui.Drawable")

---@class ui.Simple.Selection : ui.Drawable
---@operator call: ui.Simple.Selection
---@field target ui.Drawable?
local Selection = Drawable + {}

Selection.handles_keyboard_input = true

function Selection:setTarget(target)
	self.target = target
	self.world_transform = self.target.world_transform
end

---@param e ui.KeyDownEvent
function Selection:onKeyDown(e)
	if not self.target then
		return
	end

	local snap = 8
	local dx, dy = 0, 0
	local dw, dh = 0, 0

	if e.key == "a" then
		dx = -snap
	elseif e.key == "d" then
		dx = snap
	elseif e.key == "w" then
		dy = -snap
	elseif e.key == "s" then
		dy = snap
	elseif e.key == "up" then
		dh = -snap
	elseif e.key == "down" then
		dh = snap
	elseif e.key == "right" then
		dw = snap
	elseif e.key == "left" then
		dw = -snap
	end

	self.target:setBox(
		self.target:getX() + dx,
		self.target:getY() + dy,
		math.max(0, self.target:getWidth() + dw),
		math.max(0, self.target:getHeight() + dh)
	)

	self:setDimensions(self.target:getDimensions())
	self.world_transform = self.target.world_transform
end

function Selection:draw()
	if not self.target then
		return
	end

	love.graphics.setColor(1, 0, 0)
	love.graphics.setLineWidth(2)
	love.graphics.origin()
	love.graphics.applyTransform(self.world_transform)
	local w, h = self.target:getDimensions()
	love.graphics.rectangle("line", 0, 0, w, h)
end

return Selection
