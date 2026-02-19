local pkg = require("aqua.pkg")
pkg.import_love()
pkg.export_lua()

local stbl = require("stbl")
local Remote = require("icc.Remote")
local TaskHandler = require("icc.TaskHandler")
local RemoteHandler = require("icc.RemoteHandler")
local Message = require("icc.Message")

local threadId = "<threadId>"

local input_channel = love.thread.getChannel("thread_remote_input_" .. threadId)
local output_channel = love.thread.getChannel("thread_remote_output_" .. threadId)

local peer = {
	---@param _ any
	---@param msg icc.Message
	send = function(_, msg)
		output_channel:push({
			name = "message",
			msg = msg,
		})
		return 1
	end
}

local remote_handler = RemoteHandler({})
local task_handler = TaskHandler(remote_handler, "thread-" .. tostring(threadId))
local remote = Remote(task_handler, peer)

task_handler.timeout = 60

---@param ctx icc.IPeerContext
---@param obj {[any]: any}
---@param ... any
---@return table
---@return any
function remote_handler:transform(ctx, obj, ...)
	local _obj = setmetatable({}, {
		__index = obj,
		__newindex = function(t, k, v) obj[k] = v end,
	})
	_obj.remote = remote
	return _obj, ...
end

require("love.timer")

local function handle(event)
	if event.name == "stop" then
		return
	elseif event.name == "loadstring" then
		local f = assert(loadstring(event.codestring))
		remote_handler.t = f(remote, unpack(event.args, 1, event.args.n))
	elseif event.name == "message" then
		---@type icc.Message
		local msg = setmetatable(event.msg, Message)
		task_handler:handle(peer, {}, msg)
	else
		error("unknown event: " .. stbl.encode(event))
	end
end

while true do
	local event = input_channel:demand()

	if event then
		handle(event)
	end
end
