local sound = require("aqua.sound")
local bass = require("aqua.audio.bass")
local Audio = require("aqua.audio.Audio")
local ThreadPool = require("aqua.thread.ThreadPool")
local Class = require("aqua.util.Class")

local AudioManager = {}

Audio.AudioManager = AudioManager

AudioManager.audios = {}

AudioManager.update = function(self)
	for audio in pairs(self.audios) do
		audio:update()
	end
end

AudioManager.getAudio = function(self, path, manual)
	local soundData = sound.getSoundData(path)
	if not soundData then return end
	
	local audio = Audio:new()
	audio.soundData = soundData
	audio.manual = manual
	self.audios[audio] = true
	
	return audio
end

return AudioManager
