local Drawable = require("aqua.graphics.Drawable")

local Quad = Drawable:new()

Quad.reload = function(self)
	return self:calculate()
end

local draw = love.graphics.draw
Quad.draw = function(self)
	self:switchColor()
	self:switchBlendMode()
	
	return draw(
		self.image,
		self.quad,
		self._x1,
		self._y1,
		self.a,
		self.sx,
		self.sy
	)
end

Quad.batch = function(self, spriteBatch)
	spriteBatch:setColor(self.color)
	
	return spriteBatch:add(
		self.quad,
		self._x1,
		self._y1,
		self.a,
		self.sx,
		self.sy
	)
end

return Quad
