local class = require("class")
local Remote = require("icc.Remote")
local TaskHandler = require("icc.TaskHandler")
local RemoteHandler = require("icc.RemoteHandler")
local LoveThreadPeer = require("icc.LoveThreadPeer")

---@class threadremote.ThreadRemote
---@operator call: threadremote.ThreadRemote
local ThreadRemote = class()

---@param id integer
---@param t table
function ThreadRemote:new(id, t)
	self.id = id
	self.remote_handler = RemoteHandler(t)
	self.peer = LoveThreadPeer("thread_remote_input_" .. id)
	self.output_channel = love.thread.getChannel("thread_remote_output_" .. id)
	self.task_handler = TaskHandler(self.remote_handler)
	self.remote = Remote(self.task_handler, self.peer)
end

function ThreadRemote:update()
	local task_handler = self.task_handler
	local output_channel = self.output_channel
	local msg = output_channel:pop()
	while msg do
		if msg.ret then
			task_handler:handleReturn(msg)
		else
			task_handler:handleCall(self.peer, msg)
		end
		msg = output_channel:pop()
	end
end

return ThreadRemote
