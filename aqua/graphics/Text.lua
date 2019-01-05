local Sprite = require("aqua.graphics.Sprite")
local Text = Sprite:new()

Text.getY = function(self, lineCount)
	local y = self.cs:Y(self.y, true)
	if self.align.y == "center" then
		return y - self.font:getHeight() * self.scale * lineCount / 2
	elseif self.align.y == "top" then
		return y - self.font:getHeight() * self.scale * lineCount
	else
		return y
	end
end

Text.draw = function(self)
	self.scale = self.baseScale or self.cs.one / self.cs.baseOne
	
	local limit = self.cs:X(self.limit) / self.scale
	
	local width, wrappedText = self.font:getWrap(self.text, limit)
	local lineCount = #wrappedText
	
	local y = self:getY(lineCount)
	
	self:switchColor()
	self:switchFont()
	
	return love.graphics.printf(
		{self.color, self.text},
		self.cs:X(self.x, true),
		y,
		limit,
		self.align.x,
		self.r,
		self.scale,
		self.scale,
		self.ox and self.cs:X(self.ox),
		self.oy and self.cs:Y(self.oy),
		self.kx,
		self.ky
	)
end

return Text
