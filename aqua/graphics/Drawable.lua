local Sprite = require("aqua.graphics.Sprite")

local Drawable = Sprite:new()

Drawable.reload = function(self)
	self._x = self.cs:X(self.x, true)
	self._y = self.cs:Y(self.y, true)
	self._ox = self.ox and self.cs:X(self.ox)
	self._oy = self.oy and self.cs:Y(self.oy)
end

local draw = love.graphics.draw
Drawable.draw = function(self)
	self:switchColor()
	
	return draw(
		self.drawable,
		self._x,
		self._y,
		self.r,
		self.sx,
		self.sy,
		self._ox,
		self._oy
	)
end

Drawable.batch = function(self, spriteBatch)
	return spriteBatch:add(
		self._x,
		self._y,
		self.r,
		self.sx,
		self.sy,
		self._ox,
		self._oy
	)
end

return Drawable
