local Sprite = require("aqua.graphics.Sprite")

local PointSet = Sprite:new()

require("love.image")
local id = love.image.newImageData(1, 1)
id:setPixel(0, 0, 255, 255, 255, 255)
PointSet.point = love.graphics.newImage(id)

PointSet.construct = function(self, maxsprites)
	self.spriteBatch = love.graphics.newSpriteBatch(self.point, maxsprites)
end

PointSet.draw = function(self)
	self:switchColor()
	self:switchLineWidth()
	self:switchLineStyle()
	
	self.spriteBatch:clear()
	
	local points = {}
	for i = 1, #self.points do
		local point = self.points[i]
		self.spriteBatch:add(
			self.cs:X(point.x, true),
			self.cs:Y(point.y, true),
			0,
			self.cs:X(point.w),
			1
		)
	end
	
	return love.graphics.draw(self.spriteBatch, 0, 0)
end

return PointSet
