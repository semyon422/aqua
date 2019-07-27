local Class = require("aqua.util.Class")

local Drawable = Class:new()

Drawable.draw = function(self) end

Drawable.update = function(self) end

Drawable.reload = function(self) end

Drawable.receive = function(self) end

Drawable.calc1CS = function(self)
	local cs = self.cs
	
	self._x1 = cs:X(self.x, true)
	self._y1 = cs:Y(self.y, true)
	if self.w then self._w = cs:X(self.w) end
	if self.h then self._h = cs:Y(self.h) end
	if self.r then self._r = cs:X(self.r) end
	if self.limit then self._limit = cs:X(self.limit) end
end

Drawable.calc2CS = function(self)
	local cs1 = self.cs1
	local cs2 = self.cs2
	
	self._x1 = cs1:X(self.x1, true)
	self._y1 = cs1:Y(self.y1, true)
	self._x2 = cs2:X(self.x2, true)
	self._y2 = cs2:Y(self.y2, true)
	if self.w then self._w = self._x2 - self._x1 end
	if self.h then self._h = self._y2 - self._y1 end
	if self.r then
		self._r = math.sqrt((self._x2 - self._x1) ^ 2 + (self._y2 - self._y1) ^ 2)
	end
	if self.limit then self._limit = self._x2 - self._x1 end
end

Drawable.calculate = function(self)
	if self.cs1 and self.cs2 then
		return self:calc2CS()
	else
		return self:calc1CS()
	end
end

local white = {255, 255, 255, 255}
Drawable.switchColor = function(self)
	if self.color then
		love.graphics.setColor(self.color)
	else
		love.graphics.setColor(white)
	end
end

Drawable.switchFont = function(self)
	if self.font then
		love.graphics.setFont(self.font)
	end
end

Drawable.switchLineStyle = function(self)
	if self.lineStyle then
		love.graphics.setLineStyle(self.lineStyle)
	end
end

Drawable.switchLineWidth = function(self)
	if self.lineWidth then
		love.graphics.setLineWidth(self.lineWidth)
	end
end

return Drawable
