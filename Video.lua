local ok, video = pcall(require, "video")  -- c
-- local ok, video = pcall(require, "video.video")  -- ffi

if not ok then
	video = {}
	function video.open(p, s) end
end

local class = require("class")

---@class video.Video
---@operator call: video.Video
local Video = class()

---@param fileData love.FileData
---@return nil?
---@return string?
function Video:new(fileData)
	local v = video.open(fileData:getPointer(), fileData:getSize())
	if not v then
		return nil, "can't open video"
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

---@param time number
function Video:play(time)
	local v = self.video
	while time >= v:tell() and time < v:getDuration() do
		v:read(self.imageData:getPointer())
	end
	---@diagnostic disable-next-line: missing-parameter
	self.image:replacePixels(self.imageData)
end

return Video
