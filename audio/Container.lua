local class = require("class")

---@class audio.Container
---@operator call: audio.Container
local Container = class()

Container.playing = false
Container.volume = 1
Container.rate = 1
Container.pitch = 1

function Container:new()
	self.sources = {}
end

---@param source audio.Source
function Container:add(source)
	self.sources[source] = true
	source:setVolume(self.volume)
	source:setRate(self.rate)
	source:play()
end

function Container:update()
	for source in pairs(self.sources) do
		if self.playing and not source:isPlaying() then
			source:release()
			self.sources[source] = nil
		end
	end
end

function Container:release()
	for source in pairs(self.sources) do
		source:release()
	end
	self.sources = {}
	self.playing = false
end

---@param rate number
function Container:setRate(rate)
	self.rate = rate
	for source in pairs(self.sources) do
		source:setRate(rate)
	end
end

---@param volume number
function Container:setVolume(volume)
	self.volume = volume
	for source in pairs(self.sources) do
		source:setVolume(volume)
	end
end

function Container:play()
	self.playing = true
	for source in pairs(self.sources) do
		source:play()
	end
end

function Container:pause()
	self.playing = false
	for source in pairs(self.sources) do
		source:pause()
	end
end

---@param position number
function Container:setPosition(position)
	for source in pairs(self.sources) do
		local newPosition = position - source.offset
		if newPosition >= 0 and newPosition < source:getDuration() then
			source:setPosition(newPosition)
		else
			source:release()
			self.sources[source] = nil
		end
	end
end

---@return number?
---@return number?
---@return number?
function Container:getPosition()
	local position = 0
	local minPos, maxPos = math.huge, -math.huge
	local length = 0

	for source in pairs(self.sources) do
		local pos = source:getPosition()
		if source:isPlaying() then
			local _length = source:getDuration()
			local _pos = source.offset + pos
			minPos = math.min(minPos, _pos)
			maxPos = math.max(maxPos, _pos)
			position = position + _pos * _length
			length = length + _length
		end
	end

	if length == 0 then
		return
	end

	return position / length, minPos, maxPos
end

return Container
