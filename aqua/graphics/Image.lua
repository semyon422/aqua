local Drawable = require("aqua.graphics.Drawable")
local Color = require("aqua.graphics.Color")

local Image = Drawable:new()

Image.reload = function(self)
	return self:calculate()
end

local draw = love.graphics.draw
Image.draw = function(self)
	self:switchColor()
	self:switchBlendMode()
	
	return draw(
		self.image,
		self._x1,
		self._y1,
		self.a,
		self.sx,
		self.sy
	)
end

Image.batch = function(self, spriteBatch)
	spriteBatch:setColor({Color:new():set(self.color, 255):get()})
	
	return spriteBatch:add(
		self._x1,
		self._y1,
		self.a,
		self.sx,
		self.sy
	)
end

return Image
