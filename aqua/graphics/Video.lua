local Image = require("aqua.graphics.Image")

local Video = Image:new()

local draw = love.graphics.draw
Video.draw = function(self)
	if not self.video or not self.video.image then
		return
	end
	
	self:switchColor()
	
	return draw(
		self.video.image,
		self._x,
		self._y,
		self.r,
		self.sx,
		self.sy,
		self._ox,
		self._oy
	)
end

return Video
