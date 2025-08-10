local LayoutContainer = require("ui.LayoutContainer")

---@class ui.HBox.Params
---@field spacing number
---@field reverse boolean
---@field center boolean?

---@class ui.HBox : ui.LayoutContainer, ui.HBox.Params
---@overload fun(ui.HBox.Params): ui.HBox
local HBox = LayoutContainer + {}

function HBox:rearrangeChildren()
	local current_x = 0
	local spacing = self.spacing or 0

	if self.reverse then
		for i = #self.children, 1, -1 do
			local child = self.children[i]
			child:setX(current_x)
			local cw = child:getWidth()
			current_x = current_x + cw + spacing
		end
	else
		for _, child in ipairs(self.children) do
			child:setX(current_x)
			local cw = child:getWidth()
			current_x = current_x + cw + spacing
		end
	end

	self:autoSize()

	if self.center then
		for _, child in pairs(self.children) do
			child:setY((self:getHeight() - child:getHeight()) / 2)
		end
	end
end

return HBox
