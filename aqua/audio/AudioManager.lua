local bass = require("aqua.audio.bass")
local Audio = require("aqua.audio.Audio")
local ThreadPool = require("aqua.thread.ThreadPool")
local Class = require("aqua.util.Class")

local AudioManager = {}

Audio.AudioManager = AudioManager

AudioManager.chunkDatas = {}
AudioManager.audios = {}

AudioManager.update = function(self)
	for audio in pairs(self.audios) do
		audio:update()
	end
end

AudioManager.loadChunk = function(self, filePath, callback)
	if not self.chunkDatas[filePath] then
		self.chunkDatas[filePath] = {}
		local chunkData = self.chunkDatas[filePath]
		chunkData.loaded = false
		
		ThreadPool:execute(
			[[
				local filePath = ...
				local bass = require("aqua.audio.bass")
				bass.init()
				local file = love.filesystem.newFile(filePath)
				file:open("r")
				local chunk = bass.BASS_SampleLoad(true, file:read(), 0, file:getSize(), 65535, 0)
				file:close()
				return chunk
			]],
			{filePath},
			function(result)
				chunkData.chunk = result[2]
				chunkData.loaded = true
				if callback then
					callback(filePath)
				end
			end
		)
	end
end

AudioManager.unloadChunk = function(self, filePath, callback)
	if self.chunkDatas[filePath] then
		local chunkData = self.chunkDatas[filePath]
		
		ThreadPool:execute(
			[[
				local chunk = ...
				local bass = require("aqua.audio.bass")
				bass.init()
				bass.BASS_SampleFree(chunk)
			]],
			{chunkData.chunk},
			function(result)
				self.chunkDatas[filePath] = nil
				if callback then
					callback(filePath)
				end
			end
		)
	end
end

AudioManager.getAudio = function(self, filePath, manual)
	if not self.chunkDatas[filePath] or not self.chunkDatas[filePath].loaded then
		return
	end
	
	local audio = Audio:new()
	audio.chunk = self.chunkDatas[filePath].chunk
	audio.filePath = filePath
	audio.manual = manual
	self.audios[audio] = true
	
	return audio
end

return AudioManager
