local Drawable = require("aqua.graphics.Drawable")

local Stencil = Drawable:new()

local setStencilTest = love.graphics.setStencilTest
Stencil.set = function(self, comparemode, comparevalue)
	return setStencilTest(comparemode, comparevalue)
end

local stencil = love.graphics.stencil
Stencil.draw = function(self)
	return stencil(
		self.stencilfunction,
		self.action,
		self.value,
		self.keepvalues
	)
end

return Stencil
