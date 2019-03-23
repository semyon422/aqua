local Drawable = require("aqua.graphics.Drawable")

local Image = Drawable:new()

Image.reload = function(self)
	self._x = self.cs:X(self.x, true)
	self._y = self.cs:Y(self.y, true)
	self._ox = self.ox and self.cs:X(self.ox)
	self._oy = self.oy and self.cs:Y(self.oy)
end

local draw = love.graphics.draw
Image.draw = function(self)
	self:switchColor()
	
	return draw(
		self.image,
		self._x,
		self._y,
		self.r,
		self.sx,
		self.sy,
		self._ox,
		self._oy
	)
end

Image.batch = function(self, spriteBatch)
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

return Image
