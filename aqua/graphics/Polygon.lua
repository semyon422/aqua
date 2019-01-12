local Sprite = require("aqua.graphics.Sprite")

local Polygon = Sprite:new()

Polygon.reload = function(self)
	self._vertices = {}
	for i, v in ipairs(self.vertices) do
		if i % 2 == 1 then
			self._vertices[i] = self.cs:X(v, true)
		else
			self._vertices[i] = self.cs:Y(v, true)
		end
	end
end

local polygon = love.graphics.polygon
Polygon.draw = function(self)
	self:switchColor()
	self:switchLineWidth()
	self:switchLineStyle()
	
	return polygon(self.mode, self._vertices)
end

return Polygon
