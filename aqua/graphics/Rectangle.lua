local Drawable = require("aqua.graphics.Drawable")

local Rectangle = Drawable:new()

Rectangle.reload = function(self)
	self._x = self.cs:X(self.x, true)
	self._y = self.cs:Y(self.y, true)
	self._w = self.cs:X(self.w)
	self._h = self.cs:Y(self.h)
	if self.rx and self.rx > 0 then
		self._rx = self.cs:X(self.rx)
		if not self.ry or self.ry == 0 then
			self._ry = self._rx
		end
	end
	if self.ry and self.ry > 0 then
		self._ry = self.cs:Y(self.ry)
		if not self.rx or self.rx == 0 then
			self._rx = self._ry
		end
	end
end

local rectangle = love.graphics.rectangle
Rectangle.draw = function(self)
	self:switchColor()
	self:switchLineWidth()
	self:switchLineStyle()
	
	return rectangle(
		self.mode,
		self._x,
		self._y,
		self._w,
		self._h,
		self._rx,
		self._ry
	)
end

return Rectangle
