local Node = require("ui.view.Node")

---@class view.Label : view.Node
---@overload fun(text_batch_ref: ui.TextBatchRef): view.Label
local Label = Node + {}

---@param text_batch_ref ui.TextBatchRef
function Label:new(text_batch_ref)
	Node.new(self)
	self.text_batch_ref = text_batch_ref
	self.layout_box:setDimensions(self.text_batch_ref:getDimensions())
end

function Label:destroy()
	Node.destroy(self)
	self.text_batch_ref:release()
end

---@param v string
function Label:setText(v)
	self.text_batch_ref:setText(v)
	self.layout_box:setDimensions(self.text_batch_ref:getDimensions())
end

function Label:draw()
	love.graphics.draw(self.text_batch_ref.object)
end

Label.Setters = setmetatable({
	text = Label.setText
}, {__index = Node.Setters})

return Label
