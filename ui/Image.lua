local Drawable = require("ui.Drawable")

---@class ui.Image : ui.Drawable
---@operator call: ui.Image
---@field image love.Image
---@field blend_mode love.BlendMode
local Image = Drawable + {}

function Image:load()
	self:assert(self.image, "No image")
	local iw, ih = self.image:getDimensions()
	self.blend_mode = self.blend_mode or "alpha"
	self.width = self.width ~= 0 and self.width or iw
	self.height = self.height ~= 0 and self.height or ih
end

---@param image love.Image
---@param width number?
---@param height number?
function Image:replaceImage(image, width, height)
	self.image = image
	local iw, ih = self.image:getDimensions()
	self.width = width or iw
	self.height = height or ih
	self:load()
end

function Image:draw()
	love.graphics.setBlendMode(self.blend_mode)
	love.graphics.draw(self.image)
end

return Image
