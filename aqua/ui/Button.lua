local Class = require("aqua.util.Class")
local belong = require("aqua.math").belong
local TextFrame = require("aqua.graphics.TextFrame")
local Rectangle = require("aqua.graphics.Rectangle")

local Button = Class:new()

Button.construct = function(self)
	self.rectangle = Rectangle:new()
	self.textFrame = TextFrame:new()
end

Button.setText = function(self, text)
	self.textFrame.text = text
	self.textFrame:reload()
end

Button.receive = function(self, event)
	if event.name == "resize" then
		self:reload()
	elseif event.name == "mousepressed" then
		local mx = self.cs:x(event.args[1], true)
		local my = self.cs:y(event.args[2], true)
		if belong(mx, self.x, self.x + self.w) and belong(my, self.y, self.y + self.h) then
			self:interact()
		end
	end
end

Button.reload = function(self)
	local rectangle = self.rectangle
	local textFrame = self.textFrame

	rectangle.x = self.x
	rectangle.y = self.y
	rectangle.w = self.w
	rectangle.h = self.h
	rectangle.mode = self.mode
	rectangle.color = self.rectangleColor
	rectangle.lineStyle = "smooth"
	rectangle.lineWidth = 1
	rectangle.cs = self.cs
	
	textFrame.x = self.x
	textFrame.y = self.y
	textFrame.w = self.w
	textFrame.h = self.h
	textFrame.limit = self.limit
	textFrame.align = self.textAlign
	textFrame.text = self.text
	textFrame.font = self.font
	textFrame.color = self.textColor
	textFrame.cs = self.cs
	
	rectangle:reload()
	textFrame:reload()
end

Button.interact = function(self) end

Button.load = function(self) end

Button.unload = function(self) end

Button.update = function(self) end

Button.draw = function(self)
	self.rectangle:draw()
	self.textFrame:draw()
end

return Button
