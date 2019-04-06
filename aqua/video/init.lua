local video = {}

local Video = require("aqua.video.Video")

local videoDatas = {}

video.get = function(path)
	return videoDatas[path]
end

video.new = function(path)
	local videoData = Video:new()
	videoData:load(path)
	return videoData
end

video.free = function(videoData)
	return videoDatas:unload()
end

video.add = function(path, videoData)
	videoDatas[path] = videoData
end

video.remove = function(path)
	videoDatas[path] = nil
end

video.load = function(path, callback)
	if videoDatas[path] then
		return callback(videoDatas[path])
	end
	
	local videoData = video.new(path)
	video.add(path, videoData)
	callback(videoData)
end

video.unload = function(path, callback)
	video.free(videoDatas[path])
	return callback()
end

return video
