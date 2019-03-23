local Class = require("aqua.util.Class")
local belong = require("aqua.math").belong
local TextFrame = require("aqua.graphics.TextFrame")
local Rectangle = require("aqua.graphics.Rectangle")
local Stencil = require("aqua.graphics.Stencil")

local ImageButton = Class:new()

ImageButton.receive = function(self, event)
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

ImageButton.reload = function(self)
	local drawable = self.drawable
	
	self.cs = drawable.cs
	self.x = drawable.x
	self.y = drawable.y
	self.w = drawable.w
	self.h = drawable.h
	self.layer = drawable.layer
	
	self.drawable:reload()
end

ImageButton.interact = function(self) end

ImageButton.load = function(self) end

ImageButton.unload = function(self) end

ImageButton.update = function(self) end

ImageButton.draw = function(self)
	self.drawable:draw()
end

ImageButton.batch = function(self, spriteBatch)
	self.drawable:batch(spriteBatch)
end

return ImageButton
