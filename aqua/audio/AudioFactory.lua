local sound = require("aqua.sound")
local Audio = require("aqua.audio.Audio")
local Sample = require("aqua.audio.Sample")
local SampleStream = require("aqua.audio.SampleStream")
local Stream = require("aqua.audio.Stream")
local StreamUser = require("aqua.audio.StreamUser")

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
	return Stream:new({
		path = path
	})
end

AudioFactory.getStreamUser = function(self, path)
	return StreamUser:new({
		path = path
	})
end

return AudioFactory
