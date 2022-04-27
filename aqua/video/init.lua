local video = {}

video.ffmpeg = require("aqua.video.ffmpeg")

local Video = require("aqua.video.Video")

local videos = {}

video.get = function(path)
	return videos[path]
end

video.new = function(path)
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

video.load = function(path, callback)
	if videos[path] then
		return callback(videos[path])
	end

	local videoData = video.new(path)
	videos[path] = video
	callback(videoData)
end

video.unload = function(path)
	videos[path] = nil
end

return video
