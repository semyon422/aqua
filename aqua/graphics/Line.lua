local Sprite = require("aqua.graphics.Sprite")
local Line = Sprite:new()

Line.draw = function(self)
	self:switchColor()
	self:switchLineWidth()
	self:switchLineStyle()
	
	local points = {}
	for i, v in ipairs(self.points) do
		if i % 2 == 1 then
			points[i] = self.cs:X(v, true)
		else
			points[i] = self.cs:Y(v, true)
		end
	end
	
	return love.graphics.line(points)
end

return Line
