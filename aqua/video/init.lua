local video = {}

video.ffmpeg = require("aqua.video.ffmpeg")

local Video = require("aqua.video.Video")

video.newVideo = function(path)
	if not path then
		return
	end
	local info = love.filesystem.getInfo(path)
	if not info then
		return
	end
	local video = Video:new()
	video:load(path)
	return video
end

return video
