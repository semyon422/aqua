local Drawable = require("aqua.graphics.Drawable")

local Circle = Drawable:new()

Circle.reload = function(self)
	self._x = self.cs:X(self.x, true)
	self._y = self.cs:Y(self.y, true)
	self._r = self.cs:X(self.r)
end

local circle = love.graphics.circle
Circle.draw = function(self)
	self:switchColor()
	self:switchLineWidth()
	self:switchLineStyle()
	
	return circle(
		self.mode,
		self._x,
		self._y,
		self._r
	)
end

return Circle
