local Drawable = require("ui.Drawable")

---@class ui.Rectangle.Params
---@field rounding number
---@field mode "fill" | "line"
---@field line_width number

---@class ui.Rectangle : ui.Drawable, ui.Rectangle.Params
---@operator call: ui.Rectangle
local Rectangle = Drawable + {}

Rectangle.ClassName = "Rectangle"

function Rectangle:load()
	self.mode = self.mode or "fill"
	self.line_width = self.line_width or 1
	self.rounding = self.rounding or 0
end

function Rectangle:draw()
	if self.mode == "line" then
		love.graphics.setLineWidth(self.line_width)
		love.graphics.rectangle("line", 0, 0, self.width, self.height, self.rounding, self.rounding)
	else
		love.graphics.rectangle("fill", 0, 0, self.width, self.height, self.rounding, self.rounding)
	end
end

return Rectangle
