local Drawable = require("ui.Drawable")

---@class ui.Stencil.Params
---@field stencil_function function

---@class ui.Stencil : ui.Drawable
---@operator call: ui.Stencil
local Stencil = Drawable + {}

Stencil.ClassName = "Stencil"

function Stencil:beforeLoad()
	Drawable.beforeLoad(self)

	self.stencil_function = self.stencil_function or function()
		love.graphics.setColor(1, 1, 1)
		love.graphics.rectangle("fill", 0, 0, self:getWidth(), self:getHeight())
	end

	self.internal_function = function()
		love.graphics.push()
		love.graphics.applyTransform(self.world_transform)
		self.stencil_function()
		love.graphics.pop()
	end
end

function Stencil:drawChildren()
	love.graphics.stencil(self.internal_function, "replace", 1)
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
