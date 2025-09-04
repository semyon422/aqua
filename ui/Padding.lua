local LayoutContainer = require("ui.LayoutContainer")

---@class ui.Padding.Params
---@field padding number?
---@field left number?
---@field right number?
---@field top number?
---@field bottom number?

---@class ui.Padding : ui.LayoutContainer, ui.Padding.Params
---@overload fun(ui.Padding.Params): ui.Padding
local Padding = LayoutContainer + {}

Padding.ClassName = "Padding"

function Padding:rearrangeChildren()
	if #self.children > 1 then
		self:error("Padding can only have one child")
	end

	local default = self.padding or 0
	local left = self.left or default
	local right = self.right or default
	local top = self.top or default
	local bottom = self.bottom or default

	local w = self.width - left - right
	local h = self.height - top - bottom
	local c = self.children[1]
	c:setBox(left, top, w, h)
	self:autoSize()
end

return Padding
