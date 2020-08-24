local sound = require("aqua.sound")
local Audio = require("aqua.audio.Audio")
local Sample = require("aqua.audio.Sample")
local Stream = require("aqua.audio.Stream")
local StreamTempo = require("aqua.audio.StreamTempo")
local StreamMemoryTempo = require("aqua.audio.StreamMemoryTempo")
local StreamMemoryReversable = require("aqua.audio.StreamMemoryReversable")
local StreamUser = require("aqua.audio.StreamUser")
local StreamUserTempo = require("aqua.audio.StreamUserTempo")

local AudioFactory = {}

AudioFactory.getSample = function(self, path)
	local soundData = sound.get(path)
	if not soundData then return end

	return Sample:new({
		soundData = soundData,
		path = path
	})
end

AudioFactory.getStreamUser = function(self, path)
	return StreamUser:new({
		path = path
	})
end

AudioFactory.getStreamUserTempo = function(self, path)
	return StreamUserTempo:new({
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
