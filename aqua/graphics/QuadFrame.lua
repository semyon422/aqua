local ImageFrame = require("aqua.graphics.ImageFrame")

local QuadFrame = ImageFrame:new()

QuadFrame.updateBaseScale = function(self) end

local draw = love.graphics.draw
QuadFrame.draw = function(self)
	self:switchColor()
	
	return draw(
		self.image,
		self.quad,
		self._x + self._ox,
		self._y + self._oy,
		self.r,
		self.scale,
		self.scale
	)
end

QuadFrame.batch = function(self, spriteBatch)
	spriteBatch:setColor(self.color)
	
	return spriteBatch:add(
		self.quad,
		self._x + self._ox,
		self._y + self._oy,
		self.r,
		self.scale,
		self.scale
	)
end

return QuadFrame
