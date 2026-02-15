local class = require("class")

---@class view.Text
---@operator call: view.Text
---@field font love.Font
---@field font_size number
---@field text string
---@field text_batch love.Text
---@field scale number
---@field width number
---@field height number
local Text = class()

---@param font love.Font
---@param font_size number
---@param text string
function Text:new(font, font_size, text)
	self.font = assert(font, "Expected font, got nil")
	self.font_size = assert(font_size, "Expected font_size, got nil")
	self.text = assert(text, "Expected text, got nil")
	self.width = 0
	self.height = 0
	self:refresh()
end

---@param v string
function Text:setText(v)
	if self.text == v then
		return
	end
	self.text = v
	self:refresh()
end

---@param v number
function Text:setFontSize(v)
	if self.font_size == v then
		return
	end
	self.font_size = v
	self:refresh()
end

function Text:refresh()
	if not self.font or not self.text or not self.font_size then
		return
	end

	if not self.text_batch then
		self.text_batch = love.graphics.newText(self.font)
	end

	self.text_batch:set(self.text)
	local w, h = self.text_batch:getDimensions()
	self.scale = self.font_size / self.font:getHeight()
	self.width = w * self.scale
	self.height = h * self.scale
end

function Text:draw()
	if not self.text_batch then
		return
	end
	love.graphics.draw(self.text_batch, 0, 0, 0, self.scale, self.scale)
end

return Text
