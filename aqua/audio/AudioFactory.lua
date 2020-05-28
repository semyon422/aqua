local sound = require("aqua.sound")
local Audio = require("aqua.audio.Audio")
local Sample = require("aqua.audio.Sample")
local StreamFile = require("aqua.audio.StreamFile")
local StreamMemory = require("aqua.audio.StreamMemory")
local StreamMemoryReversable = require("aqua.audio.StreamMemoryReversable")

local AudioFactory = {}

AudioFactory.getSample = function(self, path)
	local soundData = sound.get(path)
	if not soundData then return end
	
	return Sample:new({
		soundData = soundData,
		path = path
	})
end

AudioFactory.getStreamFile = function(self, path)
	return StreamFile:new({
		path = path
	})
end

AudioFactory.getStreamMemory = function(self, path)
	local soundData = sound.get(path)
	if not soundData then return end

	return StreamMemoryReversable:new({
		soundData = soundData,
		path = path
	})
end

return AudioFactory
