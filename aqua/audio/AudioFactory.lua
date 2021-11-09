local sound = require("aqua.sound")
local Audio = require("aqua.audio.Audio")
local Sample = require("aqua.audio.Sample")
local Stream = require("aqua.audio.Stream")
local StreamTempo = require("aqua.audio.StreamTempo")
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
	elseif mode == "stream" then
		return AudioFactory:getStream(path)
	elseif mode == "streamTempo" then
		return AudioFactory:getStreamTempo(path)
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
	return StreamOpenAL:new({
		path = path
	})
end

AudioFactory.getSampleOpenAL = function(self, path)
	return SampleOpenAL:new({
		path = path
	})
end

AudioFactory.getSample = function(self, path)
	local soundData = sound.get(path)
	if not soundData then return end

	return Sample:new({
		soundData = soundData,
		path = path
	})
end

AudioFactory.getStream = function(self, path)
	return Stream:new({
		path = path
	})
end

AudioFactory.getStreamTempo = function(self, path)
	return StreamTempo:new({
		path = path
	})
end

AudioFactory.getStreamMemoryTempo = function(self, path)
	local soundData = sound.get(path)
	if not soundData then return end

	return StreamMemoryTempo:new({
		soundData = soundData,
		path = path
	})
end

AudioFactory.getStreamMemoryReversable = function(self, path)
	local soundData = sound.get(path)
	if not soundData then return end

	return StreamMemoryReversable:new({
		soundData = soundData,
		path = path
	})
end

return AudioFactory
