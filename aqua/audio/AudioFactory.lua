local Sample = require("aqua.audio.Sample")
local StreamMemoryTempo = require("aqua.audio.StreamMemoryTempo")

local AudioFactory = {}

AudioFactory.getAudio = function(self, soundData, mode)
	if not soundData then
		return
	end
	if mode == "sample" then
		return AudioFactory:getSample(soundData)
	elseif mode == "streamMemoryTempo" then
		return AudioFactory:getStreamMemoryTempo(soundData)
	end
end

AudioFactory.getSample = function(self, soundData)
	return Sample:new({
		soundData = soundData,
		info = soundData.info,
	})
end

AudioFactory.getStreamMemoryTempo = function(self, soundData)
	return StreamMemoryTempo:new({
		soundData = soundData,
		info = soundData.info,
	})
end

return AudioFactory
