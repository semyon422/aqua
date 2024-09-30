local pkg = require("pkg")
pkg.import_love()
pkg.export_lua()

local synctable = require("synctable")
local table_util = require("table_util")

local threadId = "<threadId>"

local inputChannel = love.thread.getChannel("input" .. threadId)
local outputChannel = love.thread.getChannel("output" .. threadId)

local thread = {}
package.loaded.thread = thread

function thread.coro() return function() error("Not allowed") end end
thread.async = thread.coro

local shared = {}
thread.shared = synctable.new(shared, function(...)
	outputChannel:push({
		name = "synctable",
		n = select("#", ...),
		...
	})
end)

require("love.timer")
_G.startTime = love.timer.getTime()

local should_stop = false

local function load_code_string(event)
	return xpcall(
		assert(loadstring(event.codestring)),
		debug.traceback,
		unpack(event.args, 1, event.args.n)
	)
end

function thread.handle(event)
	if event.name == "stop" then
		should_stop = true
	elseif event.name == "synctable" then
		synctable.set(shared, unpack(event, 1, event.n))
	elseif event.name == "init" then
		assert(load_code_string(event))
	elseif event.name == "loadstring" then
		local result = table_util.pack(load_code_string(event))
		result.name = "result"
		outputChannel:push(result)
	else
		error("unknown event " .. require("inspect")(event))
	end
end

function thread.update()
	local event = inputChannel:pop()
	while event do
		assert(event.name == "synctable")
		synctable.set(shared, unpack(event, 1, event.n))
		event = inputChannel:pop()
	end
end

while true do
	local event = inputChannel:demand()
	thread.handle(event)

	if should_stop then
		return
	end
end
