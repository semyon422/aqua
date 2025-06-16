local Drawable = require("ui.Drawable")

---@class ui.Stencil.Params
---@field stencil_function function

---@class ui.Stencil : ui.Drawable
---@operator call: ui.Stencil
local Stencil = Drawable + {}

function Stencil:load()
	self.stencil_function = self.stencil_function or function()
		love.graphics.setColor(1, 1, 1)
		love.graphics.rectangle("fill", 0, 0, self:getWidth(), self:getHeight())
	end
end

function Stencil:drawTree()
	if self.is_disabled then
		return
	end

	love.graphics.applyTransform(self.transform)
	love.graphics.stencil(self.stencil_function, "replace", 1)
	love.graphics.setStencilTest("greater", 0)

	for i = #self.children, 1, -1 do
		local child = self.children[i]
		love.graphics.push("all")
		child:drawTree()
		love.graphics.pop()
	end

	love.graphics.setStencilTest()
end

return Stencil
