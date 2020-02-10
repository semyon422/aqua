local Drawable = require("aqua.graphics.Drawable")

local Text = Drawable:new()

Text.reload = function(self)
	self:calculate()
	
	local cs = self.cs or self.cs2
	self._scale = cs.one / cs.baseOne
	local _limit = self._limit or self._w
	self._scaledLimit = _limit / self._scale
	local width, wrappedText = self.font:getWrap(self.text, self._scaledLimit)
	local lineCount = #wrappedText
	
	self._y1 = self:getY(lineCount)
	
	self._text = {self.color, self.text}
end

Text.getY = function(self, lineCount)
	local y = self._y1
	if self.align.y == "center" then
		return y - self.font:getHeight() * self._scale * lineCount / 2
	elseif self.align.y == "top" then
		return y - self.font:getHeight() * self._scale * lineCount
	else
		return y
	end
end

local printf = love.graphics.printf
Text.draw = function(self)
	self:switchColor()
	self:switchFont()
	self:switchBlendMode()
	
	return printf(
		self._text,
		self._x1,
		self._y1,
		self._scaledLimit,
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
