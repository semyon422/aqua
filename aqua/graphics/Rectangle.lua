local Drawable = require("aqua.graphics.Drawable")

local Rectangle = Drawable:new()

Rectangle.reload = function(self)
	self:calculate()
	local cs = self.cs or self.cs1
	if self.rx and self.rx > 0 then
		self._rx = cs:X(self.rx)
		if not self.ry or self.ry == 0 then
			self._ry = self._rx
		end
	end
	if self.ry and self.ry > 0 then
		self._ry = cs:Y(self.ry)
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
	self:switchBlendMode()
	
	return rectangle(
		self.mode,
		self._x1,
		self._y1,
		self._w,
		self._h,
		self._rx,
		self._ry
	)
end

return Rectangle
