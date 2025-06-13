local Drawable = require("ui.Drawable")
local Fonts = require("ui.Fonts")

---@class ui.Label.Params
---@field font_name string
---@field font_size number
---@field text string

---@class ui.Label : ui.Drawable, ui.Label.Params
---@operator call: ui.Label
local Label = Drawable + {}

function Label:load()
	local fonts = self.dependencies:get(Fonts)

	if not fonts:isFontExists(self.font_name) then
		self:error("Font doesn't exist")
	end

	self.font, self.text_scale = fonts:get(self.font_name, self.font_size)
	self.text_batch = love.graphics.newText(self.font, self.text)
	self.width, self.height = self.text_batch:getDimensions()
end

---@return number
function Label:getWidth()
	return self.width * self.text_scale
end

---@return number
function Label:getHeight()
	return self.height * self.text_scale
end

function Label:draw()
	love.graphics.scale(self.text_scale)
	love.graphics.draw(self.text_batch)
end

return Label
