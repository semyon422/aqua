local Class = require("aqua.util.Class")

local Sprite = Class:new()

Sprite.draw = function(self) end

Sprite.update = function(self) end

Sprite.reload = function(self) end

Sprite.receive = function(self) end

Sprite.switchColor = function(self)
	if self.color then
		love.graphics.setColor(self.color)
	end
end

Sprite.switchFont = function(self)
	if self.font then
		love.graphics.setFont(self.font)
	end
end

Sprite.switchLineStyle = function(self)
	if self.lineStyle then
		love.graphics.setLineStyle(self.lineStyle)
	end
end

Sprite.switchLineWidth = function(self)
	if self.lineWidth then
		love.graphics.setLineWidth(self.lineWidth)
	end
end

return Sprite
