local Sprite = require("aqua.graphics.Sprite")

local Text = Sprite:new()

Text.reload = function(self)
	self._scale = self.scale or self.cs.one / self.cs.baseOne
	
	self._limit = self.cs:X(self.limit) / self._scale
	
	local width, wrappedText = self.font:getWrap(self.text, self._limit)
	local lineCount = #wrappedText
	
	self._y = self:getY(lineCount)
	
	self._x = self.cs:X(self.x, true)
	self._ox = self.ox and self.cs:X(self.ox)
	self._oy = self.oy and self.cs:Y(self.oy)
end

Text.getY = function(self, lineCount)
	local y = self.cs:Y(self.y, true)
	if self.align.y == "center" then
		return y - self.font:getHeight() * self._scale * lineCount / 2
	elseif self.align.y == "top" then
		return y - self.font:getHeight() * self._scale * lineCount
	else
		return y
	end
end

Text.draw = function(self)
	self:switchColor()
	self:switchFont()
	
	return love.graphics.printf(
		{self.color, self.text},
		self._x,
		self._y,
		self._limit,
		self.align.x,
		self.r,
		self._scale,
		self._scale,
		self._ox,
		self._oy,
		self.kx,
		self.ky
	)
end

return Text
