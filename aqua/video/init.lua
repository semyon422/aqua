local video = {}

video.ffmpeg = require("aqua.video.ffmpeg")

local Video = require("aqua.video.Video")

local videos = {}

video.get = function(path)
	return videos[path]
end

video.new = function(path)
	if not path or not love.filesystem.exists(path) then
		return
	end
	local video = Video:new()
	video:load(path)
	return video
end

video.add = function(path, video)
	videos[path] = video
end

video.remove = function(path)
	videos[path] = nil
end

video.load = function(path, callback)
	if videos[path] then
		return callback(videos[path])
	end
	
	local videoData = video.new(path)
	video.add(path, videoData)
	callback(videoData)
end

video.unload = function(path, callback)
	videos[path] = nil
	return callback()
end

return video
