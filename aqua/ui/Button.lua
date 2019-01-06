local Class = require("aqua.util.Class")
local Observer = require("aqua.util.Observer")
local belong = require("aqua.math").belong
local TextFrame = require("aqua.graphics.TextFrame")
local Rectangle = require("aqua.graphics.Rectangle")

local Button = Class:new()

Button.rectangleColor = {255, 255, 255, 255}
Button.textColor = Button.rectangleColor
Button.mode = "line"
Button.lineStyle = "smooth"
Button.lineWidth = 1
Button.layer = 0
Button.font = love.graphics.getFont()

Button.construct = function(self)
	self.rectangle = Rectangle:new({
		x = self.x,
		y = self.y,
		w = self.w,
		h = self.h,
		mode = self.mode,
		color = self.rectangleColor,
		cs = self.cs
	})
	self.rectangle:reload()
	
	self.textFrame = TextFrame:new({
		x = self.x,
		y = self.y,
		w = self.w,
		h = self.h,
		limit = self.w,
		align = self.textAlign,
		text = self.text,
		font = self.font,
		color = self.textColor,
		cs = self.cs
	})
	self.textFrame:reload()
end

Button.receive = function(self, event)
	if event.name == "resize" then
		self.rectangle:reload()
		self.textFrame:reload()
	elseif event.name == "mousepressed" then
		local mx = self.cs:x(event.args[1], true)
		local my = self.cs:y(event.args[2], true)
		if belong(mx, self.x, self.x + self.w) and belong(my, self.y, self.y + self.h) then
			self:interact()
		end
	end
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
