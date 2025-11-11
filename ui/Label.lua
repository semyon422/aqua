local Node = require("ui.Node")

---@class ui.Label : ui.Node
---@operator call: ui.Label
---@field font love.Font
---@field text string
---@field shadow boolean?
---@field shadow_x number
---@field shadow_y number
local Label = Node + {}

Label.ClassName = "Label"

function Label:new(params)
	self.text = ""
	self.shadow_x = 1
	self.shadow_y = 1
	Node.new(self, params)
	self:assert(self.font, "No font was provided")

	self.text_batch = love.graphics.newText(self.font, self.text)
	self:setDimensions(self.text_batch:getDimensions())
end

---@param text string
function Label:setText(text)
	if self.text == text then
		return
	end
	self.text = text
	self.text_batch:set(text)
	self:setDimensions(self.text_batch:getDimensions())
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
