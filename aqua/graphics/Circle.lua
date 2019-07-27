local Drawable = require("aqua.graphics.Drawable")

local Circle = Drawable:new()

Circle.reload = function(self)
	return self:calculate()
end

local circle = love.graphics.circle
Circle.draw = function(self)
	self:switchColor()
	self:switchLineWidth()
	self:switchLineStyle()
	
	return circle(
		self.mode,
		self._x1,
		self._y1,
		self._r
	)
end

return Circle
