local pkg = require("aqua.pkg")
pkg.import_love()
pkg.export_lua()

local Remote = require("icc.Remote")
local TaskHandler = require("icc.TaskHandler")

local table_util = require("table_util")

local threadId = "<threadId>"

local inputChannel = love.thread.getChannel("input" .. threadId)
local outputChannel = love.thread.getChannel("output" .. threadId)

require("love.timer")

local function load_code_string(event)
	return xpcall(
		assert(loadstring(event.codestring)),
		debug.traceback,
		unpack(event.args, 1, event.args.n)
	)
end

local function handle(event)
	if event.name == "stop" then
		return
	elseif event.name == "loadstring" then
		local result = table_util.pack(load_code_string(event))
		result.name = "result"
		outputChannel:push(result)
	else
		error("unknown event " .. require("inspect")(event))
	end
end

while true do
	local event = inputChannel:pop()

	if event then
		handle(event)
	else
		love.timer.sleep(0.001)
	end
end
