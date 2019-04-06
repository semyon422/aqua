local ImageFrame = require("aqua.graphics.ImageFrame")

local VideoFrame = ImageFrame:new()

local draw = love.graphics.draw
VideoFrame.draw = function(self)
	if not self.video or not self.video.image then
		return
	end
	
	self:switchColor()
	
	return draw(
		self.video.image,
		self._x + self._ox,
		self._y + self._oy,
		self.r,
		self.scale,
		self.scale
	)
end

return VideoFrame
