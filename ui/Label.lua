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

	if not fonts:isFontExist(self.font_name) then
		self:error("Font doesn't exist")
	end

	self.font = fonts:get(self.font_name, self.font_size)
	self.text_batch = love.graphics.newText(self.font, self.text)
	local width, height = self.text_batch:getDimensions()
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
	love.graphics.draw(self.text_batch)
end

return Label
