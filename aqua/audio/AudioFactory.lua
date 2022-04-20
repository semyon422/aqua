local sound = require("aqua.sound")
local Sample = require("aqua.audio.Sample")
local StreamMemoryTempo = require("aqua.audio.StreamMemoryTempo")
local StreamMemoryReversable = require("aqua.audio.StreamMemoryReversable")
local StreamOpenAL = require("aqua.audio.StreamOpenAL")
local SampleOpenAL = require("aqua.audio.SampleOpenAL")

local AudioFactory = {}

AudioFactory.getAudio = function(self, path, mode)
	if not path then
		return
	end
	if mode == "sample" then
		return AudioFactory:getSample(path)
	elseif mode == "streamMemoryTempo" then
		return AudioFactory:getStreamMemoryTempo(path)
	elseif mode == "streamMemoryReversable" then
		return AudioFactory:getStreamMemoryReversable(path)
	elseif mode == "streamOpenAL" then
		return AudioFactory:getStreamOpenAL(path)
	elseif mode == "sampleOpenAL" then
		return AudioFactory:getSampleOpenAL(path)
	end
end

AudioFactory.getStreamOpenAL = function(self, path)
	return StreamOpenAL:new({path = path})
end

AudioFactory.getSampleOpenAL = function(self, path)
	return SampleOpenAL:new({path = path})
end

AudioFactory.getSample = function(self, path)
	local soundData = sound.get(path)
	if not soundData then return end

	return Sample:new({
		soundData = soundData,
		info = soundData.info,
	})
end

AudioFactory.getStreamMemoryTempo = function(self, path)
	local soundData = sound.get(path)
	if not soundData then return end

	return StreamMemoryTempo:new({
		soundData = soundData,
		info = soundData.info,
	})
end

AudioFactory.getStreamMemoryReversable = function(self, path)
	local soundData = sound.get(path)
	if not soundData then return end

	return StreamMemoryReversable:new({
		soundData = soundData,
		info = soundData.info,
	})
end

return AudioFactory
