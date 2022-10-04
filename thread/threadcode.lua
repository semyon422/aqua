package.path = love.filesystem.getRequirePath()
package.cpath = love.filesystem.getCRequirePath()

local threadId = "<threadId>"

local internalInputChannel = love.thread.getChannel("internalInput" .. threadId)
local internalOutputChannel = love.thread.getChannel("internalOutput" .. threadId)
local inputChannel = love.thread.getChannel("input" .. threadId)
local outputChannel = love.thread.getChannel("output" .. threadId)

local synctable = require("synctable")

local thread = {}
package.loaded.thread = thread

function thread.coro() return function() error("Not allowed") end end
thread.async = thread.coro

local shared = {}
thread.shared = synctable.new(shared, function(...)
	-- print("send", synctable.format("thread", ...))
	outputChannel:push({...})
end)
thread.update = function()
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
		local p = event.params
		local status, q, w, e, r, t, y, u, i = xpcall(
			loadstring(event.codestring),
			debug.traceback,
			p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8]
		)
		internalOutputChannel:push({status, q, w, e, r, t, y, u, i})
	end
end
