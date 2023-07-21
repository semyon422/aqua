local ok, video = pcall(require, "video")  -- c
-- local ok, video = pcall(require, "video.video")  -- ffi

if not ok then
	video = {}
	function video.open(p, s) end
end

local class = require("class_new2")

local Video = class()

function Video:new(fileData)
	local v = video.open(fileData:getPointer(), fileData:getSize())
	if not v then
		return nil
	end

	self.video = v
	self.fileData = fileData
	self.imageData = love.image.newImageData(v:getDimensions())
	self.image = love.graphics.newImage(self.imageData)
end

function Video:release()
	self.video:close()
	self.imageData:release()
	self.image:release()
end

function Video:rewind()
	local v = self.video
	v:seek(0)
	v:read(self.imageData:getPointer())
end

function Video:play(time)
	local v = self.video
	while time >= v:tell() do
		v:read(self.imageData:getPointer())
	end
	self.image:replacePixels(self.imageData)
end

return Video
