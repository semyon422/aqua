local sound = require("aqua.sound")
local bass = require("aqua.audio.bass")
local Audio = require("aqua.audio.Audio")
local ThreadPool = require("aqua.thread.ThreadPool")
local Class = require("aqua.util.Class")
local Group = require("aqua.util.Group")

local AudioManager = {}

Audio.AudioManager = AudioManager

AudioManager.audios = Group:new()

AudioManager.update = function(self)
	self.audios:call(function(audio) return audio:update() end)
end

AudioManager.stop = function(self)
	self.audios:call(function(audio) return audio:stop() end)
	self:update()
end

AudioManager.rate = function(self, rate)
	self.audios:call(function(audio) return audio:rate(rate) end)
end

AudioManager.getAudio = function(self, path, manual)
	local soundData = sound.get(path)
	if not soundData then return end
	
	local audio = Audio:new({
		soundData = soundData,
		manual = manual
	})
	self.audios:add(audio)
	
	return audio
end

return AudioManager
