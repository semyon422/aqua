local Drawable = require("ui.Drawable")
local Rectangle = require("ui.Rectangle")
local Stencil = require("ui.Stencil")

---@class ui.Simple.WindowTopBar : ui.Drawable
---@operator call: ui.Simple.WindowTopBar
local WindowTopBar = Drawable + {}

function WindowTopBar:load()
	self.accepts_input = true
	self.position_origin = { x = 0, y = 0 }
	self.drag_origin = { x = 0, y = 0 }

	self:add(Rectangle({
		width = self:getWidth(),
		height = self:getHeight(),
		color = { 0.5, 0.2, 0.5, 0.8 }
	}))
end

---@param e ui.DragStartEvent
function WindowTopBar:onDragStart(e)
	self.position_origin.x = self.parent:getX()
	self.position_origin.y = self.parent:getY()
	self.drag_origin.x = e.x
	self.drag_origin.y = e.y
end

---@param e ui.DragStartEvent
function WindowTopBar:onDrag(e)
	local dx = self.drag_origin.x - e.x
	local dy = self.drag_origin.y - e.y
	local viewport_scale = (768 / love.graphics.getHeight()) -- TODO: get it from viewport
	self.parent:setPosition(
		self.position_origin.x - dx * viewport_scale,
		self.position_origin.y - dy * viewport_scale
	)
end

return WindowTopBar
