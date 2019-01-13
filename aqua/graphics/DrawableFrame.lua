local Sprite = require("aqua.graphics.Sprite")

local DrawableFrame = Sprite:new()

DrawableFrame.reload = function(self)
	self:updateScale()
	self:updateOffsets()
	
	self._x = self.cs:X(self.x, true)
	self._y = self.cs:Y(self.y, true)
end

DrawableFrame.updateScale = function(self)
	self.scale = 1
	local dw = self.drawable:getWidth()
	local dh = self.drawable:getHeight()
	local s1 = self.cs:X(self.w) / self.cs:Y(self.h) <= dw / dh
	local s2 = self.cs:X(self.w) / self.cs:Y(self.h) >= dw / dh
	
	if self.locate == "out" and s1 or self.locate == "in" and s2 then
		self.scale = self.cs:Y(self.h) / dh
	elseif self.locate == "out" and s2 or self.locate == "in" and s1 then
		self.scale = self.cs:X(self.w) / dw
	end
end

DrawableFrame.getOffset = function(self, screen, frame, align)
	if align == "center" then
		return (screen - frame) / 2
	elseif align == "left" or align == "top" then
		return 0
	elseif align == "right" or align == "bottom" then
		return screen - frame
	end
end

DrawableFrame.updateOffsets = function(self)
	self._ox = self:getOffset(self.cs:X(self.w), self.drawable:getWidth() * self.scale, self.align.x)
	self._oy = self:getOffset(self.cs:Y(self.h), self.drawable:getHeight() * self.scale, self.align.y)
end

local draw = love.graphics.draw
DrawableFrame.draw = function(self)
	self:switchColor()
	
	return love.graphics.draw(
		self.drawable,
		self._x + self._ox,
		self._y + self._oy,
		self.r,
		self.scale,
		self.scale
	)
end

return DrawableFrame
