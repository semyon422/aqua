local LayoutContainer = require("ui.LayoutContainer")

---@class ui.VBox.Params
---@field spacing number
---@field reverse boolean

---@class ui.VBox : ui.LayoutContainer, ui.VBox.Params
---@overload fun(ui.VBox.Params): ui.VBox
local VBox = LayoutContainer + {}

VBox.ClassName = "VBox"

VBox.size_mode = VBox.SizeMode.Auto

function VBox:rearrangeChildren()
	local current_y = 0
	local spacing = self.spacing or 0

	if self.reverse then
		for i = #self.children, 1, -1 do
			local child = self.children[i]
			child:setY(current_y)
			local ch = child:getHeight()
			current_y = current_y + ch + spacing
		end
	else
		for _, child in ipairs(self.children) do
			child:setY(current_y)
			local ch = child:getHeight()
			current_y = current_y + ch + spacing
		end
	end

	-- Updates it for the second time for each child...
	-- TODO: fix this the smart way
	self:updateWorldTransform()
end

return VBox
