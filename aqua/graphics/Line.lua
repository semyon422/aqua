local Sprite = require("aqua.graphics.Sprite")

local Line = Sprite:new()

Line.reload = function(self)
	self._points = {}
	for i, v in ipairs(self.points) do
		if i % 2 == 1 then
			self._points[i] = self.cs:X(v, true)
		else
			self._points[i] = self.cs:Y(v, true)
		end
	end
end

Line.draw = function(self)
	self:switchColor()
	self:switchLineWidth()
	self:switchLineStyle()
	
	return love.graphics.line(self._points)
end

return Line
