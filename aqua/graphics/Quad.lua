local Sprite = require("aqua.graphics.Sprite")

local Quad = Sprite:new()

Quad.draw = function(self)
	self:switchColor()
	
	return love.graphics.draw(
		self.drawable,
		self.quad,
		self.cs:X(self.x, true),
		self.cs:Y(self.y, true),
		self.r,
		self.sx,
		self.sy,
		self.ox and self.cs:X(self.ox),
		self.oy and self.cs:X(self.oy)
	)
end

return Quad
