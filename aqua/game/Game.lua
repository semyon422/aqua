local Class = require("aqua.util.Class")
local Container = require("aqua.graphics.Container")
local ThreadPool = require("aqua.thread.ThreadPool")
local ScreenManager = require("aqua.screen.ScreenManager")
local Observer = require("aqua.util.Observer")
local aquaio = require("aqua.io")

local Game = Class:new()

Game.construct = function(self)
	self.observer = Observer:new()
	self.observer.receive = function(_, ...) return self:receive(...) end
	self.globalUI = Container:new()
	self.screenManager = ScreenManager:new()
	self.screenManager.game = self
end

Game.run = function(self)
	self:load()
	aquaio:add(self.observer)
end

Game.load = function(self)
	self.globalUI:reload()
end

Game.update = function(self)
	ThreadPool:update()
	self.globalUI:update()
	self.screenManager:update()
end

Game.draw = function(self)
	self.screenManager:draw()
	self.globalUI:draw()
end

Game.unload = function(self)
	self.screenManager:unload()
	self.globalUI = Container:unload()
end

Game.receive = function(self, event)
	if event.name == "update" then
		self:update()
	elseif event.name == "draw" then
		self:draw()
	end
end

return Game
