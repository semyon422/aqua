local Node = require("ui.view.Node")
local Text = require("ui.view.Text")

---@class view.Label : view.Node
---@overload fun(text: view.Text): view.Label
---@field label view.Text
local Label = Node + {}

---@param font love.Font
---@param text string
function Label:new(font, text)
	Node.new(self)
	self.text_obj = Text(font, text)
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
	text = Label.setText
}, { __index = Node.Setters })

return Label
