local Sprite = require("aqua.graphics.Sprite")
local TextFrame = Sprite:new()

TextFrame.getY = function(self, lineCount)
	local y = self.cs:Y(self.y, true)
	local h = self.cs:Y(self.h)
	if self.align.y == "center" then
		return y + (h - self.font:getHeight() * lineCount * self.scale) / 2
	elseif self.align.y == "bottom" then
		return y + h - self.font:getHeight() * lineCount * self.scale
	else
		return y
	end
end

return TextFrame
