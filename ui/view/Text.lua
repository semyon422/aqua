local class = require("class")

---@class view.Text
---@operator call: view.Text
---@field font love.Font
---@field text string
---@field text_batch love.Text
---@field width number
---@field height number
local Text = class()

---@param font love.Font
---@param text string
function Text:new(font, text)
	self.font = assert(font, "Expected font, got nil")
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

function Text:refresh()
	if not self.font or not self.text then
		return
	end

	if not self.text_batch then
		self.text_batch = love.graphics.newText(self.font)
	end

	self.text_batch:set(self.text)
	local w, h = self.text_batch:getDimensions()
	self.width = w
	self.height = h
end

function Text:draw()
	if not self.text_batch then
		return
	end
	love.graphics.draw(self.text_batch, 0, 0)
end

return Text
