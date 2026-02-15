local Node = require("ui.view.Node")
local Text = require("ui.view.Text")

---@class view.Label : view.Node
---@overload fun(text: view.Text): view.Label
---@field label view.Text
local Label = Node + {}

---@param font love.Font
---@param font_size number
---@param text string
function Label:new(font, font_size, text)
	Node.new(self)
	self.text_obj = Text(font, font_size, text)
	self.layout_box:setDimensions(self.text_obj.width, self.text_obj.height)
end

---@param v number
function Label:setFontSize(v)
	self.text_obj:setFontSize(v)
	self.layout_box:setDimensions(self.text_obj.width, self.text_obj.height)
end

---@param v string
function Label:setText(v)
	self.text_obj:setText(v)
	self.layout_box:setDimensions(self.text_obj.width, self.text_obj.height)
end

function Label:draw()
	self.text_obj:draw()
end

Label.Setters = setmetatable({
	font_size = Label.setFontSize,
	text = Label.setText
}, { __index = Node.Setters })

return Label
