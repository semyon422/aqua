local sound = require("aqua.sound")
local Audio = require("aqua.audio.Audio")
local Sample = require("aqua.audio.Sample")
local SampleStream = require("aqua.audio.SampleStream")
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

AudioFactory.getStream = function(self, path)
	return StreamMemory:new({
		path = path
	})
end

return AudioFactory
