local ok, video = pcall(require, "video")  -- c
if not ok then
	return function() end
end

-- local ok, video = pcall(require, "video.video")  -- ffi
-- if not ok then
-- 	return function() end
-- end

local class = require("class_new")

local Video, new = class()

Video.new = function(self, fileData)
	local v = video.open(fileData:getPointer(), fileData:getSize())
	if not v then
		return nil
	end

	self.video = v
	self.fileData = fileData
	self.imageData = love.image.newImageData(v:getDimensions())
	self.image = love.graphics.newImage(self.imageData)
end

Video.release = function(self)
	self.video:close()
	self.imageData:release()
	self.image:release()
end

Video.rewind = function(self)
	local v = self.video
	v:seek(0)
	v:read(self.imageData:getPointer())
end

Video.play = function(self, time)
	local v = self.video
	while time >= v:tell() do
		v:read(self.imageData:getPointer())
	end
	self.image:replacePixels(self.imageData)
end

return new
