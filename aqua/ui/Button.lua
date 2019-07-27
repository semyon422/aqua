local Class = require("aqua.util.Class")
local belong = require("aqua.math").belong
local TextFrame = require("aqua.graphics.TextFrame")
local Rectangle = require("aqua.graphics.Rectangle")
local Stencil = require("aqua.graphics.Stencil")

local Button = Class:new()

Button.enableStencil = false
Button.stencilColor = {255, 255, 255, 255}

Button.construct = function(self)
	self.background = Rectangle:new()
	self.border = Rectangle:new()
	self.textFrame = TextFrame:new()
	self.stencilFrame = Rectangle:new({
		color = self.stencilColor
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

Button.reloadBackground = function(self)
	local background = self.background
	
	background.x = self.x
	background.y = self.y
	background.x1 = self.x1
	background.y1 = self.y1
	background.x2 = self.x2
	background.y2 = self.y2
	background.w = self.w
	background.h = self.h
	background.rx = math.min(self.rx, self.w / 2)
	background.ry = math.min(self.ry, self.h / 2)
	background.mode = "fill"
	background.color = self.backgroundColor
	background.cs = self.cs
	background.cs1 = self.cs1
	background.cs2 = self.cs2
	
	background:reload()
end

Button.reloadBorder = function(self)
	local border = self.border
	
	border.x = self.x
	border.y = self.y
	border.x1 = self.x1
	border.y1 = self.y1
	border.x2 = self.x2
	border.y2 = self.y2
	border.w = self.w
	border.h = self.h
	border.rx = math.min(self.rx, self.w / 2)
	border.ry = math.min(self.ry, self.h / 2)
	border.mode = "line"
	border.color = self.borderColor
	border.lineStyle = self.lineStyle
	border.lineWidth = self.lineWidth
	border.cs = self.cs
	border.cs1 = self.cs1
	border.cs2 = self.cs2
	
	border:reload()
end

Button.reloadTextFrame = function(self)
	local textFrame = self.textFrame
	
	textFrame.x = self.x + self.xpadding
	textFrame.y = self.y
	textFrame.x1 = self.x1 and self.x1 + self.xpadding
	textFrame.y1 = self.y1
	textFrame.x2 = self.x2 and self.x2 - self.xpadding
	textFrame.y2 = self.y2
	textFrame.w = self.w - 2 * self.xpadding
	textFrame.h = self.h
	textFrame.limit = self.limit
	textFrame.align = self.textAlign
	textFrame.text = self.text
	textFrame.font = self.font
	textFrame.color = self.textColor
	textFrame.cs = self.cs
	textFrame.cs1 = self.cs1
	textFrame.cs2 = self.cs2
	
	textFrame:reload()
end

Button.reloadStencilFrame = function(self)
	local stencilFrame = self.stencilFrame
	
	stencilFrame.x = self.x
	stencilFrame.y = self.y
	stencilFrame.x1 = self.x1
	stencilFrame.y1 = self.y1
	stencilFrame.x2 = self.x2
	stencilFrame.y2 = self.y2
	stencilFrame.w = self.w
	stencilFrame.h = self.h
	stencilFrame.rx = math.min(self.rx, self.w / 2)
	stencilFrame.ry = math.min(self.ry, self.h / 2)
	stencilFrame.mode = "fill"
	stencilFrame.cs = self.cs
	stencilFrame.cs1 = self.cs1
	stencilFrame.cs2 = self.cs2
	
	stencilFrame:reload()
end

Button.reload = function(self)
	self:reloadBackground()
	self:reloadBorder()
	self:reloadTextFrame()
	self:reloadStencilFrame()
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
	self.background:draw()
	self.textFrame:draw()
	if self.enableStencil then
		self.stencil:set()
	end
	self.border:draw()
end

return Button
