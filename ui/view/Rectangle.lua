local Node = require("ui.view.Node")

---@class view.Rectangle : view.Node
---@operator call: view.Rectangle
local Rectangle = Node + {}

function Rectangle:draw()
	love.graphics.rectangle("fill", 0, 0, self.layout_box.x.size, self.layout_box.y.size)
end

return Rectangle
