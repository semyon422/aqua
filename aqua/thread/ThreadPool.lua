local Thread = require("aqua.thread.Thread")
local Observable = require("aqua.util.Observable")
local Class = require("aqua.util.Class")

local ThreadPool = {}

ThreadPool.inputObservable = Observable:new()
ThreadPool.outputObservable = Observable:new()
ThreadPool.observable = ThreadPool.outputObservable

ThreadPool.poolSize = 4
ThreadPool.keepAliveTime = 1

ThreadPool.threads = {}
ThreadPool.queue = {}

ThreadPool.send = function(self, event)
	return self.outputObservable:send(event)
end

ThreadPool.receive = function(self, event)
	return self.inputObservable:send(event)
end

ThreadPool.execute = function(self, task)
	self.queue[#self.queue + 1] = task
	return self:update()
end

ThreadPool.update = function(self)
	local currentTime = love.timer.getTime()

	for i = 1, self.poolSize do
		local thread = self.threads[i]
		if thread then
			thread:update()
			if thread.idle and currentTime - thread.lastTime > self.keepAliveTime then
				thread:stop()
				self.inputObservable:remove(thread)
				self.threads[i] = nil
			end
		end
	end

	if self.queue[1] then
		local thread = self:getIdleThread()
		if thread then
			thread:execute(self.queue[1])
			table.remove(self.queue, 1)
		end
	end
end

ThreadPool.getIdleThread = function(self)
	local thread
	for i = 1, self.poolSize do
		thread = self.threads[i]
		if thread and thread.idle then
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

	self.inputObservable:add(thread)

	thread.pool = self
	thread.id = threadId
	thread:create(self.codestring:format(threadId))
	thread:start()

	self.threads[threadId] = thread

	return thread
end

ThreadPool.codestring = [[
	local threadId = %d

	local internalInputChannel = love.thread.getChannel("internalInput" .. threadId)
	local internalOutputChannel = love.thread.getChannel("internalOutput" .. threadId)
	local inputChannel = love.thread.getChannel("input" .. threadId)
	local outputChannel = love.thread.getChannel("output" .. threadId)

	thread = {}
	thread.pop = function(self)
		return inputChannel:pop()
	end
	thread.push = function(self, event)
		return outputChannel:push(event)
	end

	require("preloaders.preloadall")

	require("love.timer")
	startTime = love.timer.getTime()

	local event
	while true do
		event = internalInputChannel:demand()
		if event.name == "stop" then
			internalOutputChannel:push(true)
			return
		elseif event.name == "loadstring" then
			local status, err = xpcall(
				loadstring(event.codestring),
				debug.traceback,
				event.params
			)
			internalOutputChannel:push({status, err})
		end
	end
]]

return ThreadPool
