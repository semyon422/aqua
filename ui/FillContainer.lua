local LayoutContainer = require("ui.LayoutContainer")

---@class ui.FillContainer : ui.LayoutContainer
---@operator call: ui.FillContainer
local FillContainer = LayoutContainer + {}

function FillContainer:beforeLoad()
	LayoutContainer.beforeLoad(self)
	self:setDimensions(self.parent:getDimensions())
end

function FillContainer:updateTree(ctx)
	LayoutContainer.updateTree(self, ctx)

	local pw, ph = self.parent:getDimensions()
	local w, h = self:getDimensions()

	if pw ~= w or ph ~= h then
		self:setDimensions(self.parent:getDimensions())
	end
end

return FillContainer
