local AudioOpenAL = require("aqua.audio.AudioOpenAL")

local StreamOpenAL = AudioOpenAL:new()

StreamOpenAL.construct = function(self)
	if not self.path then
		return
	end
	self.source = love.audio.newSource(self.path, "stream")
end

return StreamOpenAL
