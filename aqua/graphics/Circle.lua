local Sprite = require("aqua.graphics.Sprite")
local Circle = Sprite:new()

Circle.draw = function(self)
	self:switchColor()
	self:switchLineWidth()
	self:switchLineStyle()
	
	return love.graphics.circle(
		self.mode,
		self.cs:X(self.x, true),
		self.cs:Y(self.y, true),
		self.cs:X(self.r)
	)
end

return Circle
