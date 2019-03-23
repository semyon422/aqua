local DrawableFrame = require("aqua.graphics.DrawableFrame")

local QuadFrame = DrawableFrame:new()

QuadFrame.updateBaseScale = function(self) end

local draw = love.graphics.draw
QuadFrame.draw = function(self)
	self:switchColor()
	
	return draw(
		self.drawable,
		self.quad,
		self._x + self._ox,
		self._y + self._oy,
		self.r,
		self.scale,
		self.scale
	)
end

QuadFrame.batch = function(self, spriteBatch) print(self.scale)
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
