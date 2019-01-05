local Class = require("aqua.util.Class")
local Screen = require("aqua.screen.Screen")

local ScreenManager = Class:new()

ScreenManager.construct = function(self)
	self.currentScreen = Screen:new()
end

ScreenManager.set = function(self, screen)
	self.currentScreen:unload()
	self.currentScreen = screen
	screen:load()
end

ScreenManager.update = function(self)
	self.currentScreen:update()
end

ScreenManager.draw = function(self)
	self.currentScreen:draw()
end

return ScreenManager
