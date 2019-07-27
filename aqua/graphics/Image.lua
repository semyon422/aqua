local Drawable = require("aqua.graphics.Drawable")

local Image = Drawable:new()

Image.reload = function(self)
	return self:calculate()
end

local draw = love.graphics.draw
Image.draw = function(self)
	self:switchColor()
	
	return draw(
		self.image,
		self._x1,
		self._y1,
		self.a,
		self.sx,
		self.sy
	)
end

Image.batch = function(self, spriteBatch)
	spriteBatch:setColor(self.color)
	
	return spriteBatch:add(
		self._x1,
		self._y1,
		self.a,
		self.sx,
		self.sy
	)
end

return Image
