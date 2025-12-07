local Node = require("ui.view.Node")

---@class view.Image : view.Node
---@operator call: view.Image
---@field image love.Image
local Image = Node + {}

Image.ClassName = "Image"

---@param params { image: love.Image }
function Image:init(params)
	Node.init(self, params)
	assert(self.image, "Expected image, got nil")
	self.layout_box:setDimensions(self.image:getDimensions())
end

---@param image love.Image
function Image:setImage(image)
	self.image = image
	self.layout_box:setDimensions(self.image:getDimensions())
end

function Image:draw()
	love.graphics.draw(self.image)
end

return Image
