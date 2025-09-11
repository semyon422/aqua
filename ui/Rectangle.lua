local Drawable = require("ui.Drawable")
local rectangle = require("ui.primitives.rectangle")

---@class ui.Rectangle.Params
---@field rounding number
---@field line_width number?

---@class ui.Rectangle : ui.Drawable, ui.Rectangle.Params
---@operator call: ui.Rectangle
local Rectangle = Drawable + {}

Rectangle.ClassName = "Rectangle"

function Rectangle:load()
	self.rounding = self.rounding or 0
end

function Rectangle:draw()
	rectangle(self:getWidth(), self:getHeight(), self.rounding, self.line_width)
end

return Rectangle
