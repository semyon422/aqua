local IPeer = require("icc.IPeer")
local table_util = require("table_util")
local Remote = require("icc.Remote")
local TaskHandler = require("icc.TaskHandler")
local RemoteHandler = require("icc.RemoteHandler")
local Message = require("icc.Message")

---@type string
local codestring

---@param id any
---@return string
local function getCodeString(id)
	if not codestring then
		local path = "aqua/threadremote/threadcode.lua"
		codestring = love.filesystem.read(path)
	end
	if type(id) ~= "number" then
		id = ("%q"):format(id)
	end
	return (codestring:gsub('"<threadId>"', id))
end

---@class threadremote.ThreadRemote: icc.IPeer
---@operator call: threadremote.ThreadRemote
local ThreadRemote = IPeer + {}
---@param id integer
---@param t table
function ThreadRemote:new(id, t)
	self.id = id
	self.t = t

	self.input_channel = love.thread.getChannel("thread_remote_input_" .. id)
	self.output_channel = love.thread.getChannel("thread_remote_output_" .. id)
	self.input_channel:clear()
	self.output_channel:clear()

	self.remote_handler = RemoteHandler(t)
	self.task_handler = TaskHandler(self.remote_handler, "thread-" .. tostring(id))
	self.remote = Remote(self.task_handler, self)

	self.task_handler.timeout = 60

	self.thread = love.thread.newThread(getCodeString(id))

	---@param ctx icc.IPeerContext
	---@param obj {[any]: any}
	---@param ... any
	---@return table
	---@return any
	function self.remote_handler.transform(_, ctx, obj, ...)
		local _obj = setmetatable({}, {
			__index = obj,
			__newindex = function(t, k, v) obj[k] = v end,
		})
		_obj.remote = self.remote
		return _obj, ...
	end
end

---@param f fun(remote: table, ...: any): ...: any
---@param ... any
function ThreadRemote:start(f, ...)
	self.thread:start()

	self.input_channel:push({
		name = "loadstring",
		codestring = string.dump(f),
		args = table_util.pack(...),
	})
end

---@param msg icc.Message
---@return integer?
---@return string?
function ThreadRemote:send(msg)
	self.input_channel:push({
		name = "message",
		msg = msg,
	})
	return 1
end

function ThreadRemote:update()
	local task_handler = self.task_handler

	local output_channel = self.output_channel
	local event = output_channel:pop()
	while event do
		if event.name == "message" then
			---@type icc.Message
			local msg = setmetatable(event.msg, Message)
			task_handler:handle(self, {}, msg)
		end
		event = output_channel:pop()
	end
end

function ThreadRemote:reset()
	self.input_channel:clear()
	self.output_channel:clear()
	-- Cancel all pending tasks to resume coroutines waiting for responses
	local task_handler = self.task_handler
	local callbacks = task_handler.callbacks
	task_handler.callbacks = {}
	task_handler.timeouts = {}
	for _, cb in pairs(callbacks) do
		cb(false, "ThreadRemote reset")
	end
end

function ThreadRemote:stop()
	self.input_channel:push({name = "stop"})
	self:reset()
end

return ThreadRemote
