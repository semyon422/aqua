local Class = require("aqua.util.Class")

local Container = Class:new()

Container.volume = 1

Container.construct = function(self)
	self.audios = {}
	self.audioList = {}
	self.needSort = false
end

Container.add = function(self, audio)
	self.audios[audio] = true
	self.needSort = true
	audio:setVolume(self.volume)
end

Container.remove = function(self, audio)
	self.audios[audio] = nil
	self.needSort = true
end

Container.sort = function(self)
	if not self.needSort then
		return
	end
	
	local audios = {}
	for audio in pairs(self.audios) do
		audios[#audios + 1] = audio
		audio:update()
	end
	
	table.sort(audios, function(a, b)
		return a.position < b.position
	end)
	
	self.audioList = audios
	
	self.needSort = false
end

Container.update = function(self)
	self:sort()
	
	local audioList = self.audioList
	for i = 1, #audioList do
		local audio = audioList[i]
		audio:update()
		if not audio.playing then
			audio:free()
			self:remove(audio)
		end
	end
end

Container.stop = function(self)
	local audioList = self.audioList
	for i = 1, #audioList do
		audioList[i]:stop()
	end
end

Container.setRate = function(self, rate)
	local audioList = self.audioList
	for i = 1, #audioList do
		audioList[i]:setRate(rate)
	end
end

Container.setPitch = function(self, pitch)
	local audioList = self.audioList
	for i = 1, #audioList do
		audioList[i]:setPitch(pitch)
	end
end

Container.setVolume = function(self, volume)
	self.volume = volume
	local audioList = self.audioList
	for i = 1, #audioList do
		audioList[i]:setVolume(volume)
	end
end

Container.play = function(self)
	local audioList = self.audioList
	for i = 1, #audioList do
		audioList[i]:play()
	end
end

Container.pause = function(self)
	local audioList = self.audioList
	for i = 1, #audioList do
		audioList[i]:pause()
	end
end

Container.getPosition = function(self)
	local position = 0
	local length = 0
	
	local audioList = self.audioList
	for i = 1, #audioList do
		local audio = audioList[i]
		if audio.playing then
			position = position + (audio.offset + audio.position) * audio.length
			length = length + audio.length
		end
	end
	
	if length == 0 then
		return nil
	end
	
	return position / length
end

return Container
