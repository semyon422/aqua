local Sprite = require("aqua.graphics.Sprite")

local Rectangle = Sprite:new()

Rectangle.reload = function(self)
	self._x = self.cs:X(self.x, true)
	self._y = self.cs:Y(self.y, true)
	self._w = self.cs:X(self.w)
	self._h = self.cs:Y(self.h)
end

Rectangle.draw = function(self)
	self:switchColor()
	self:switchLineWidth()
	self:switchLineStyle()
	
	return love.graphics.rectangle(
		self.mode,
		self._x,
		self._y,
		self._w,
		self._h
	)
end

return Rectangle
