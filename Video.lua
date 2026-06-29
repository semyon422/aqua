local ok, video = pcall(require, "video") -- c
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
	self.time = 0
end

function Video:release()
	self.video:close()
	self.imageData:release()
	self.image:release()
end

function Video:rewind()
	self:seek(0)
end

---@param time number
function Video:seek(time)
	self.video:seek(time)
	self.time = -math.huge
	self:play(time)
end

---@param time number
function Video:play(time)
	local v = self.video
	local frame_time = v:readAt(self.imageData:getPointer(), time)
	if frame_time then
		self.time = frame_time
		---@diagnostic disable-next-line: missing-parameter
		self.image:replacePixels(self.imageData)
	end
end

return Video
