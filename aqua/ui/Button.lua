local Class = require("aqua.util.Class")
local belong = require("aqua.math").belong
local TextFrame = require("aqua.graphics.TextFrame")
local Rectangle = require("aqua.graphics.Rectangle")
local Stencil = require("aqua.graphics.Stencil")

local Button = Class:new()

Button.enableStencil = false
Button.stencilColor = {255, 255, 255, 255}

Button.construct = function(self)
	self.rectangle = Rectangle:new()
	self.textFrame = TextFrame:new()
	self.stencilFrame = Rectangle:new({
		color = stencilColor
	})
	self.stencil = Stencil:new({
		stencilfunction = function() self.stencilFrame:draw() end,
		action = "replace",
		value = 1,
		keepvalues = false
	})
end

Button.setText = function(self, text)
	self.text = text
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
			self:interact(event)
		end
	end
end

Button.reload = function(self)
	local rectangle = self.rectangle
	local textFrame = self.textFrame
	local stencilFrame = self.stencilFrame

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
	
	stencilFrame.x = self.x
	stencilFrame.y = self.y
	stencilFrame.w = self.w
	stencilFrame.h = self.h
	stencilFrame.cs = self.cs
	stencilFrame.mode = "fill"
	
	rectangle:reload()
	textFrame:reload()
	stencilFrame:reload()
end

Button.interact = function(self) end

Button.load = function(self) end

Button.unload = function(self) end

Button.update = function(self) end

Button.draw = function(self)
	if self.enableStencil then
		self.stencil:draw()
		self.stencil:set("greater", 0)
	end
	self.rectangle:draw()
	self.textFrame:draw()
	if self.enableStencil then
		self.stencil:set()
	end
end

return Button
