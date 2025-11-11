local Node = require("ui.Node")
local Assets = require("ui.Assets")

---@class ui.Image : ui.Node
---@operator call: ui.Image
---@field image love.Image
local Image = Node + {}

Image.ClassName = "Image"

function Image:new(params)
	self.image = Assets.getEmptyImage()
	Node.new(self, params)
	self:setDimensions(self.image:getDimensions())
end

---@param image love.Image
function Image:setImage(image)
	self.image = image
	self:setDimensions(self.image:getDimensions())
end

function Image:draw()
	love.graphics.draw(self.image)
end

return Image
