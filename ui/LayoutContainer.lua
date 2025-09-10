local Drawable = require("ui.Drawable")

---@class ui.LayoutContainer : ui.Drawable
---@operator call: ui.LayoutContainer
local LayoutContainer = Drawable + {}

LayoutContainer.ClassName = "LayoutContainer"

function LayoutContainer:invalidateLayout()
	if self.invalidating == true then
		return
	end
	self.invalidating = true
	self:rearrangeChildren()
	self.invalidating = false
end

function LayoutContainer:rearrangeChildren() end

return LayoutContainer
