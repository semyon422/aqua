local Node = require("ui.view.Node")

---@class view.Label : view.Node
---@overload fun(font_or_text_batch: love.Font | love.Text, text: string?): view.Label
local Label = Node + {}

---@param font_or_text_batch love.Font | love.Text
---@param text string?
function Label:new(font_or_text_batch, text)
	Node.new(self)

	if font_or_text_batch:type() == "Font" then
		---@cast font_or_text_batch love.Font
		self.text_batch = love.graphics.newText(font_or_text_batch)
	elseif font_or_text_batch:type() == "Text" then
		---@cast font_or_text_batch love.Text
		self.text_batch = font_or_text_batch
	end

	if text then
		self.text_batch:set(text)
	end

	self.layout_box:setDimensions(self.text_batch:getDimensions())
end

---@param v string
function Label:setText(v)
	self.text_batch:set(v)
	self.layout_box:setDimensions(self.text_batch:getDimensions())
end

function Label:draw()
	love.graphics.draw(self.text_batch)
end

Label.Setters = setmetatable({
	text = Label.setText
}, {__index = Node.Setters})

return Label
