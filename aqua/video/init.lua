local aquathread = require("aqua.thread")
local _video = require("video")

local video = {}

local Video = {}

Video.release = function(self)
	self.video:close()
	self.imageData:release()
	self.image:release()
end

Video.rewind = function(self)
	local v = self.video
	v:seek(0)
	v:read(self.imageData:getPointer())  -- need to read twice on some videos
	v:read(self.imageData:getPointer())
end

Video.play = function(self, time)
	local v = self.video
	repeat until not (time >= v:tell() and v:read(self.imageData:getPointer()))
	self.image:replacePixels(self.imageData)
end

video.newVideo = function(path)
	require("love.filesystem")
	local fileData = love.filesystem.newFileData(path)
	if not fileData then
		return
	end

	local v = setmetatable({}, {__index = Video})
	v.fileData = fileData

	if not love.graphics then
		return v
	end

	local _video = require("video")
	local _v = _video.open(fileData:getPointer(), fileData:getSize())
	if not _v then
		return
	end
	v.video = _v

	require("love.image")

	v.imageData = love.image.newImageData(_v:getDimensions())
	v.image = love.graphics.newImage(v.imageData)

	return v
end

local newVideoAsync = aquathread.async(function(path)
	local video = require("aqua.video")
	return video.newVideo(path)
end)

video.newVideoAsync = function(path)
	local v = newVideoAsync(path)
	if not v then return end

	local fileData = v.fileData
	local _v = _video.open(fileData:getPointer(), fileData:getSize())
	if not _v then
		return
	end

	v.video = _v
	v.imageData = love.image.newImageData(_v:getDimensions())
	v.image = love.graphics.newImage(v.imageData)

	return setmetatable(v, {__index = Video})
end

return video
