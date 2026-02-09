local Node = require("ui.view.Node")

---@class view.Label : view.Node
---@operator call: view.Label
---@field font love.Font
---@field font_size number
---@field text string
local Label = Node + {}

function Label:new()
	Node.new(self)
	self.content_dirty = false
end

---@param v love.Font
function Label:setFont(v)
	if self.font == v then
		return
	end
	self.font = v
	self:updateTextBatch()
end

---@param v number
function Label:setFontSize(v)
	if self.font_size == v then
		return
	end
	self.font_size = v
	self:updateTextBatch()
end

---@param v string
function Label:setText(v)
	if self.text == v then
		return
	end
	self.text = v
	self:updateTextBatch()
end

function Label:updateTextBatch()
	if not self.font or not self.text or not self.font_size then
		return
	end

	if not self.text_batch then
		self.text_batch = love.graphics.newText(self.font)
	end

	self.text_batch:set(self.text)
	local w, h = self.text_batch:getDimensions()
	self.scale = self.font_size / self.font:getHeight()
	self.layout_box:setDimensions(w * self.scale, h * self.scale)
end

function Label:draw()
	love.graphics.draw(self.text_batch, 0, 0, 0, self.scale, self.scale)
end

Label.Setters = setmetatable({
	font = Label.setFont,
	font_size = Label.setFontSize,
	text = Label.setText
}, { __index = Node.Setters })

return Label
