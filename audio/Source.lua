local Class = require("Class")

local Source = Class:new()

Source.rateValue = 1
Source.offset = 0
Source.baseVolume = 1

Source.release = function(self) end

Source.play = function(self) end
Source.pause = function(self) end
Source.stop = function(self) end

Source.isPlaying = function(self) end
Source.setRate = function(self, rate) end
Source.setPitch = function(self, pitch) end
Source.getPosition = function(self) end
Source.setPosition = function(self, position) end
Source.getLength = function(self) end
Source.setBaseVolume = function(self, volume) end
Source.setVolume = function(self, volume) end

return Source
