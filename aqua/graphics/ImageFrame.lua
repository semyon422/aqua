local Drawable = require("aqua.graphics.Drawable")

local ImageFrame = Drawable:new()

ImageFrame.reload = function(self)
	self:calculate()
	self:updateBaseScale()
	self:updateScale()
	self:updateOffsets()
end

ImageFrame.updateBaseScale = function(self)
	self.bw = self.image:getWidth()
	self.bh = self.image:getHeight()
end

ImageFrame.updateScale = function(self)
	self._scale = 1
	local dw = self.bw
	local dh = self.bh
	local s1 = self._w / self._h <= dw / dh
	local s2 = self._w / self._h >= dw / dh
	
	if self.locate == "out" and s1 or self.locate == "in" and s2 then
		self._scale = self._h / dh
	elseif self.locate == "out" and s2 or self.locate == "in" and s1 then
		self._scale = self._w / dw
	end
	
	self._scale = self._scale * (self.scale or 1)
end

ImageFrame.getOffset = function(self, screen, frame, align)
	if align == "center" then
		return (screen - frame) / 2
	elseif align == "left" or align == "top" then
		return 0
	elseif align == "right" or align == "bottom" then
		return screen - frame
	end
end

ImageFrame.updateOffsets = function(self)
	self._ox = self:getOffset(self._w, self.bw * self._scale, self.align.x)
	self._oy = self:getOffset(self._h, self.bh * self._scale, self.align.y)
end

local draw = love.graphics.draw
ImageFrame.draw = function(self)
	self:switchColor()
	self:switchBlendMode()
	
	return draw(
		self.image,
		self._x1 + self._ox,
		self._y1 + self._oy,
		self.a,
		self._scale,
		self._scale
	)
end

ImageFrame.batch = function(self, spriteBatch)
	spriteBatch:setColor(self.color)
	
	return spriteBatch:add(
		self._x1 + self._ox,
		self._y1 + self._oy,
		self.a,
		self._scale,
		self._scale
	)
end

return ImageFrame
