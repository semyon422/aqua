package.path = love.filesystem.getRequirePath()
package.cpath = love.filesystem.getCRequirePath()

local synctable = require("synctable")
local table_util = require("table_util")

local threadId = "<threadId>"

local internalInputChannel = love.thread.getChannel("internalInput" .. threadId)
local internalOutputChannel = love.thread.getChannel("internalOutput" .. threadId)
local inputChannel = love.thread.getChannel("input" .. threadId)
local outputChannel = love.thread.getChannel("output" .. threadId)

local thread = {}
package.loaded.thread = thread

function thread.coro() return function() error("Not allowed") end end
thread.async = thread.coro

local shared = {}
thread.shared = synctable.new(shared, function(...)
	-- print("send", synctable.format("thread", ...))
	outputChannel:push({...})
end)
function thread.update()
	local event = inputChannel:pop()
	while event do
		-- print("receive", synctable.format("thread", unpack(event)))
		synctable.set(shared, unpack(event))
		event = inputChannel:pop()
	end
end
thread.update()

require("preloaders.preloadall")

require("love.timer")
_G.startTime = love.timer.getTime()

local event
while true do
	event = internalInputChannel:demand()
	if event.name == "stop" then
		internalOutputChannel:push(true)
		return
	elseif event.name == "loadstring" then
		local result = table_util.pack(xpcall(
			assert(loadstring(event.codestring)),
			debug.traceback,
			unpack(event.args, 1, event.args.n)
		))
		internalOutputChannel:push(result)
	end
end
