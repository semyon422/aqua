local Sprite = require("aqua.graphics.Sprite")

local Rectangle = Sprite:new()

Rectangle.draw = function(self)
	self:switchColor()
	self:switchLineWidth()
	self:switchLineStyle()
	
	return love.graphics.rectangle(
		self.mode,
		self.cs:X(self.x, true),
		self.cs:Y(self.y, true),
		self.cs:X(self.w),
		self.cs:Y(self.h)
	)
end

return Rectangle
