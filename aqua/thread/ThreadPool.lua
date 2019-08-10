local Thread = require("aqua.thread.Thread")
local Observable = require("aqua.util.Observable")
local Class = require("aqua.util.Class")

local ThreadPool = {}

ThreadPool.observable = Observable:new()

ThreadPool.poolSize = 4
ThreadPool.keepAliveTime = 1

ThreadPool.threads = {}
ThreadPool.queue = {}

ThreadPool.send = function(self, event)
	return self.observable:send(event)
end

ThreadPool.execute = function(self, codestring, args, callback)
	self.queue[#self.queue + 1] = {codestring, args, callback}
	return self:update()
end

ThreadPool.update = function(self)
	local currentTime = love.timer.getTime()
	
	for i = 1, self.poolSize do
		local thread = self.threads[i]
		if thread then
			thread:update()
			if thread.idle and currentTime - thread.lastTime > self.keepAliveTime then
				thread.callback = self.threadStopCallback
				thread:send({
					action = "stop"
				})
				self.threads[i] = nil
			end
		end
	end
	
	if self.queue[1] then
		local thread = self:getIdleThread()
		if thread then
			thread:execute(unpack(self.queue[1]))
			table.remove(self.queue, 1)
		end
	end
end

ThreadPool.threadStopCallback = function(thread) end

ThreadPool.getIdleThread = function(self)
	local thread
	for i = 1, self.poolSize do
		thread = self.threads[i]
		if thread and thread:isIdle() then
			return thread
		end
	end
	
	for i = 1, self.poolSize do
		if not self.threads[i] then
			return self:createThread(i)
		end
	end
end

ThreadPool.createThread = function(self, threadId)
	local thread = Thread:new()
	thread.pool = self
	thread.id = threadId
	thread:create(self.codestring:format(("%q"):format(package.path), threadId))
	thread:start()
	self.threads[threadId] = thread
	return thread
end

ThreadPool.codestring = [[
	package.path = %s
	local aqua = require("aqua")
	
	local threadId = %d
	local inputChannel = love.thread.getChannel("input" .. threadId)
	local outputChannel = love.thread.getChannel("output" .. threadId)
	
	require("love.timer")
	startTime = love.timer.getTime()
	
	local event
	while true do
		event = inputChannel:demand()
		if event.action == "stop" then
			outputChannel:push({
				done = true
			})
			return
		elseif event.action == "loadstring" then
			local status1, err1 = xpcall(
				loadstring,
				debug.traceback,
				event.codestring
			)
			if not status1 then
				outputChannel:push({
					result = {status1, err1 .. "\n" .. event.trace},
					done = true
				})
			else
				local status2, err2 = xpcall(
					err1,
					debug.traceback,
					unpack(event.args)
				)
				if not status2 then
					err2 = err2 .. "\n" .. event.trace
				end
				outputChannel:push({
					result = {status2, err2},
					done = true
				})
			end
		end
	end
]]

return ThreadPool
