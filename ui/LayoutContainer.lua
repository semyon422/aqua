local Drawable = require("ui.Drawable")

---@class ui.LayoutContainer : ui.Drawable
---@operator call: ui.LayoutContainer
local LayoutContainer = Drawable + {}

function LayoutContainer:updateTree(ctx)
	Drawable.updateTree(self, ctx)

	if self.invalidated then
		self:rearrangeChildren()
		self.invalidated = false
	end
end

function LayoutContainer:invalidateLayout()
	if self.is_killed then
		return
	end
	Drawable.invalidateLayout(self)
	self.invalidated = true
end

function LayoutContainer:rearrangeChildren() end

return LayoutContainer
