local Class = require("aqua.util.Class")

local Drawable = Class:new()

Drawable.draw = function(self) end

Drawable.update = function(self) end

Drawable.reload = function(self) end

Drawable.receive = function(self) end

Drawable.switchColor = function(self)
	if self.color then
		love.graphics.setColor(self.color)
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
