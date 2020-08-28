local AudioOpenAL = require("aqua.audio.AudioOpenAL")

local SampleOpenAL = AudioOpenAL:new()

SampleOpenAL.construct = function(self)
	if not self.path then
		return
	end
	self.source = love.audio.newSource(self.path, "sample")
end

return SampleOpenAL
