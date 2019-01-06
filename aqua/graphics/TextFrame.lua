local Text = require("aqua.graphics.Text")

local TextFrame = Text:new()

TextFrame.getY = function(self, lineCount)
	local y = self.cs:Y(self.y, true)
	local h = self.cs:Y(self.h)
	if self.align.y == "center" then
		return y + (h - self.font:getHeight() * lineCount * self._scale) / 2
	elseif self.align.y == "bottom" then
		return y + h - self.font:getHeight() * lineCount * self._scale
	else
		return y
	end
end

return TextFrame
