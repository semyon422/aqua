local sound = require("aqua.sound")
local bass = require("aqua.audio.bass")
local Audio = require("aqua.audio.Audio")
local ThreadPool = require("aqua.thread.ThreadPool")
local Class = require("aqua.util.Class")

local AudioManager = {}

Audio.AudioManager = AudioManager

AudioManager.audios = {}
AudioManager.streams = {}

AudioManager.update = function(self)
	for audio in pairs(self.audios) do
		audio:update()
	end
end

AudioManager.stop = function(self)
	for audio in pairs(self.audios) do
		audio:stop()
	end
	self:update()
end

AudioManager.getAudio = function(self, path, manual)
	local soundData = sound.get(path)
	if not soundData then return end
	
	local audio = Audio:new({
		soundData = soundData,
		manual = manual
	})
	self.audios[audio] = true
	
	return audio
end

return AudioManager
