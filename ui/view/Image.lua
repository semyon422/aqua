local Node = require("ui.view.Node")

---@class view.Image : view.Node
---@operator call: view.Image
---@field image love.Image
local Image = Node + {}

-- Rounded corners SDF
-- Outline SDF
-- Grayscale Rec. 709 weights
-- Pixelate
-- Chromatic Aberration
-- Vignette (Highlighing something)

---@param image love.Image
function Image:setImage(image)
	self.image = image
	self.layout_box:setDimensions(self.image:getDimensions())
end

function Image:draw()
	love.graphics.draw(self.image)
end

Image.Setters = setmetatable({
	image = Image.setImage
}, {__index = Node.Setters})

return Image
