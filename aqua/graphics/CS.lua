local map = require("aqua.math").map
local Class = require("aqua.util.Class")

local CS = Class:new()

CS.reload = function(self)
	if self.binding == "all" then
		self.one = math.min(self.screenHeight, self.screenWidth)
		self.onex = self.screenWidth
		self.oney = self.screenHeight
		return
	end
	
	if self.binding == "h" then
		self.one = self.screenHeight
	elseif self.binding == "w" then
		self.one = self.screenWidth
	elseif self.binding == "min" then
		self.one = math.min(self.screenHeight, self.screenWidth)
	elseif self.binding == "max" then
		self.one = math.max(self.screenHeight, self.screenWidth)
	else
		self.one = 1
	end
	self.onex = self.one
	self.oney = self.one
end

CS.aX = function(self, x)
	return map(x, 0, 1, 0, self.screenWidth)
end

CS.aY = function(self, y)
	return map(y, 0, 1, 0, self.screenHeight)
end

CS.x = function(self, X, g)
	if g then
		return (X - self:aX(self.bx)) / self.onex + self.rx
	else
		return X / self.onex
	end
end

CS.y = function(self, Y, g)
	if g then
		return (Y - self:aY(self.by)) / self.oney + self.ry
	else
		return Y / self.oney
	end
end

CS.X = function(self, x, g)
	if g then
		return (x - self.rx) * self.onex + self:aX(self.bx)
	else
		return x * self.onex
	end
end

CS.Y = function(self, y, g)
	if g then
		return (y - self.ry) * self.oney + self:aY(self.by)
	else
		return y * self.oney
	end
end

return CS
