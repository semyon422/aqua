local Drawable = require("aqua.graphics.Drawable")
local Color = require("aqua.graphics.Color")

local Text = Drawable:new()

Text.reload = function(self)
	self:calculate()
	
	local cs = self.cs or self.cs2
	self._scale = cs.one / cs.baseOne
	local _limit = self._limit or self._w
	self._scaledLimit = _limit / self._scale

	local width, wrappedText = 0, ""
	local status, err1, err2 = pcall(self.font.getWrap, self.font, self.text, self._scaledLimit)
	if status then
		width, wrappedText = err1, err2
	else
		width, wrappedText = self.font:getWrap(err1, self._scaledLimit)
	end

	local lineCount = #wrappedText
	
	self._y1 = self:getY(lineCount)
	
	self._text = {{Color:new():set(self.color, 255):get()}, self.text}
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

	local status, err = pcall(
		printf,
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

	if not status then
		printf(
			{self._text[1], err},
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
end

return Text
