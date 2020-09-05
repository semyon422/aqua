local AudioOpenAL = require("aqua.audio.AudioOpenAL")

local SampleOpenAL = AudioOpenAL:new()

SampleOpenAL.construct = function(self)
	local info = love.filesystem.getInfo(self.path)
	if not self.path and not info then
		return
	end
	local status, source = pcall(love.audio.newSource, self.path, "sample")
	if not status then
		return
	end
	self.source = source
end

return SampleOpenAL
