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

---@param last_frame_time number?
---@param requested_time number
---@param frame_rate number?
---@return boolean
local function shouldSeek(last_frame_time, requested_time, frame_rate)
	if not last_frame_time then
		return true
	end

	local frame_duration = (frame_rate and frame_rate > 0 and 1 / frame_rate) or 1 / 30
	local delta = requested_time - last_frame_time
	if delta < -frame_duration then
		return true
	end

	return delta > frame_duration * 3
end

---@param frame_rate number?
---@return number
local function getFrameDuration(frame_rate)
	if frame_rate and frame_rate > 0 then
		return 1 / frame_rate
	end
	return 1 / 30
end

---@param fileData love.FileData
---@return nil?
---@return string?
function Video:new(fileData)
	local v = video.open(fileData:getPointer(), fileData:getSize())
	if not v then
		return nil, "can't open video"
	end

	local width, height = v:getDimensions()
	self.video = v
	self.fileData = fileData
	self.imageData = love.image.newImageData(width, height)
	self.image = love.graphics.newImage(self.imageData)
	self.time = nil
	self.frame_rate = v.getFrameRate and v:getFrameRate() or nil
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
	self.time = nil
	self:play(time)
end

---@param time number
function Video:play(time)
	time = math.max(time, 0)
	local v = self.video
	local frame_time
	if shouldSeek(self.time, time, self.frame_rate) then
		frame_time = v:readAt(self.imageData:getPointer(), time)
	else
		local min_frame_time = time - getFrameDuration(self.frame_rate) * 0.5
		local reads = 0
		-- Gameplay draw calls this every frame. Keep the current image while it is
		-- close enough to the playback clock, and use sequential read() to catch up.
		-- Calling readAt() here would seek and flush decoder state every draw.
		while self.time and self.time < min_frame_time and reads < 4 do
			frame_time = v:read(self.imageData:getPointer())
			if not frame_time then
				break
			end
			self.time = frame_time
			reads = reads + 1
		end
	end
	if frame_time then
		self.time = frame_time
		---@diagnostic disable-next-line: missing-parameter
		self.image:replacePixels(self.imageData)
	end
end

return Video
