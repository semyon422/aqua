local sound = require("aqua.sound")
local Audio = require("aqua.audio.Audio")

local AudioFactory = {}

AudioFactory.getAudio = function(self, path)
	local soundData = sound.get(path)
	if not soundData then return end
	
	return Audio:new({
		soundData = soundData
	})
end

return AudioFactory
