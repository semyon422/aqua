local Node = require("ui.Node")
local rectangle = require("ui.primitives.rectangle")

---@class ui.Rectangle : ui.Node
---@operator call: ui.Rectangle
---@field line_width number? border in pixels
local Rectangle = Node + {}

Rectangle.ClassName = "Rectangle"

function Rectangle:new(params)
	self.rounding = 0
	Node.new(self, params)
end

function Rectangle:draw()
	rectangle(self.width, self.height, self.rounding, self.line_width)
end

return Rectangle
