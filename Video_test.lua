local test = {}

---@class video_test.Calls
---@field read integer
---@field readAt integer
---@field seek integer

---@return fun()
local function installFakeLove()
	---@type table?
	local old_love = love
	love = {
		image = {
			newImageData = function()
				return {
					getPointer = function()
						return "ptr"
					end,
					release = function() end,
				}
			end,
		},
		graphics = {
			newImage = function()
				return {
					replacePixels = function() end,
					release = function() end,
				}
			end,
		},
	}
	return function()
		love = old_love
	end
end

---@param frame_rate number
---@return video.Video
---@return video_test.Calls
---@return fun()
local function loadVideoWithFakeBackend(frame_rate)
	---@type function?
	local old_preload = package.preload.video
	---@type any
	local old_video = package.loaded.video
	---@type any
	local old_Video = package.loaded.Video
	local restore_love = installFakeLove()

	---@type video_test.Calls
	local calls = {
		read = 0,
		readAt = 0,
		seek = 0,
	}
	local frame_time = 0
	package.loaded.video = nil
	package.loaded.Video = nil
	package.preload.video = function()
		return {
			open = function()
				return {
					getDimensions = function()
						return 1, 1
					end,
					getFrameRate = function()
						return frame_rate
					end,
					readAt = function(_, _, time)
						calls.readAt = calls.readAt + 1
						frame_time = time
						return frame_time
					end,
					read = function()
						calls.read = calls.read + 1
						frame_time = frame_time + 1 / frame_rate
						return frame_time
					end,
					seek = function()
						calls.seek = calls.seek + 1
					end,
					close = function() end,
				}
			end,
		}
	end

	local Video = require("Video")
	local function restore()
		package.preload.video = old_preload
		package.loaded.video = old_video
		package.loaded.Video = old_Video
		restore_love()
	end
	return Video, calls, restore
end

local fake_file_data = {
	getPointer = function()
		return "file"
	end,
	getSize = function()
		return 1
	end,
}

---@param t testing.T
function test.play_keeps_current_frame_while_clock_is_close(t)
	local Video, calls, restore = loadVideoWithFakeBackend(30)
	local video = Video(fake_file_data)

	video:play(0)
	video:play(1 / 60)

	t:eq(calls.readAt, 1)
	t:eq(calls.read, 0)
	restore()
end

---@param t testing.T
function test.play_keeps_frame_when_clock_is_slightly_behind_video(t)
	local Video, calls, restore = loadVideoWithFakeBackend(30)
	local video = Video(fake_file_data)

	video:play(1 / 30)
	video:play(1 / 60)

	t:eq(calls.readAt, 1)
	t:eq(calls.read, 0)
	restore()
end

---@param t testing.T
function test.play_clamps_negative_time(t)
	local Video, calls, restore = loadVideoWithFakeBackend(30)
	local video = Video(fake_file_data)

	video:play(-0.5)
	video:play(-0.25)

	t:eq(video.time, 0)
	t:eq(calls.readAt, 1)
	t:eq(calls.read, 0)
	restore()
end

---@param t testing.T
function test.play_reads_sequential_frames_without_seek(t)
	local Video, calls, restore = loadVideoWithFakeBackend(30)
	local video = Video(fake_file_data)

	video:play(0)
	video:play(1 / 30)

	t:eq(calls.readAt, 1)
	t:eq(calls.read, 1)
	restore()
end

---@param t testing.T
function test.play_uses_readAt_for_large_jump(t)
	local Video, calls, restore = loadVideoWithFakeBackend(30)
	local video = Video(fake_file_data)

	video:play(0)
	video:play(1)

	t:eq(calls.readAt, 2)
	t:eq(calls.read, 0)
	restore()
end

return test
