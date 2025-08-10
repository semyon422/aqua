local LayoutContainer = require("ui.LayoutContainer")

---@class ui.Padding.Params
---@field padding number

---@class ui.Padding : ui.LayoutContainer, ui.Padding.Params
---@overload fun(ui.Padding.Params): ui.Padding
local Padding = LayoutContainer + {}

function Padding:rearrangeChildren()
	if #self.children > 1 then
		self:error("Padding can only have one child")
	end

	local w = self.width - self.padding * 2
	local h = self.height - self.padding * 2
	local c = self.children[1]
	c:setBox(self.padding, self.padding, w, h)
	self:autoSize()
end

return Padding
