local Drawable = require("aqua.graphics.Drawable")

local Quad = Drawable:new()

Quad.reload = function(self)
	self._x = self.cs:X(self.x, true)
	self._y = self.cs:Y(self.y, true)
	self._ox = self.ox and self.cs:X(self.ox)
	self._oy = self.oy and self.cs:Y(self.oy)
end

local draw = love.graphics.draw
Quad.draw = function(self)
	self:switchColor()
	
	return draw(
		self.image,
		self.quad,
		self._x,
		self._y,
		self.r,
		self.sx,
		self.sy,
		self._ox,
		self._oy
	)
end

Quad.batch = function(self, spriteBatch)
	spriteBatch:setColor(self.color)
	
	return spriteBatch:add(
		self.quad,
		self._x,
		self._y,
		self.r,
		self.sx,
		self.sy,
		self._ox,
		self._oy
	)
end

return Quad
