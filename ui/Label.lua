local Drawable = require("ui.Drawable")
local Fonts = require("ui.Fonts")

---@class ui.Label.Params
---@field font_name string
---@field font_size number
---@field text string
---@field shadow boolean?
---@field shadow_x number?
---@field shadow_y number?

---@class ui.Label : ui.Drawable, ui.Label.Params
---@operator call: ui.Label
local Label = Drawable + {}

function Label:load()
	local fonts = self.dependencies:get(Fonts)

	if not fonts:isFontExist(self.font_name) then
		self:error("Font doesn't exist")
	end

	self.font = fonts:get(self.font_name, self.font_size)
	self.text_batch = love.graphics.newText(self.font, self.text)
	self.shadow_x = self.shadow_x or -1
	self.shadow_y = self.shadow_y or 1
	local width, height = self.text_batch:getWidth(), self.font:getHeight()
	self:setWidth(width)
	self:setHeight(height)
end

---@param text string
function Label:replaceText(text)
	if self.text == text then
		return
	end
	self.text = text
	self.text_batch = love.graphics.newText(self.font, self.text)
	local width, height = self.text_batch:getDimensions()
	self:setWidth(width)
	self:setHeight(height)
end

function Label:draw()
	if self.shadow then
		local r, g, b, a = love.graphics.getColor()
		love.graphics.setColor(1 - r, 1 - g, 1 - b, a * 0.5)
		love.graphics.draw(self.text_batch, self.shadow_x, self.shadow_y)
		love.graphics.setColor(r, g, b, a)
	end
	love.graphics.draw(self.text_batch)
end

return Label
