local Thread = require("aqua.thread.Thread")
local Observable = require("aqua.util.Observable")

local ThreadPool = {}

ThreadPool.inputObservable = Observable:new()
ThreadPool.outputObservable = Observable:new()
ThreadPool.observable = ThreadPool.outputObservable

ThreadPool.poolSize = 4
ThreadPool.keepAliveTime = 1

ThreadPool.threads = {}
ThreadPool.runningThreads = {}
ThreadPool.queue = {}
ThreadPool.loaded = true

ThreadPool.send = function(self, event)
	return self.outputObservable:send(event)
end

ThreadPool.receive = function(self, event)
	return self.inputObservable:send(event)
end

ThreadPool.execute = function(self, task)
	if not self.loaded then
		return
	end
	self.queue[#self.queue + 1] = task
	return self:update()
end

ThreadPool.isRunning = function(self)
	return next(self.runningThreads) ~= nil
end

ThreadPool.waitAsync = function(self)
	assert(not self.loaded, "attempt to waitAsync when ThreadPool is loaded")
	assert(not self.waiting, "attempt to waitAsync while waitingAsync")
	if not self:isRunning() then
		return
	end
	self.waiting = coroutine.running()
	coroutine.yield()
end

ThreadPool.unload = function(self)
	self.queue = {}
	for _, thread in pairs(self.threads) do
		thread:stop()
	end
	self.loaded = false
end

ThreadPool.update = function(self)
	local currentTime = love.timer.getTime()

	for i, thread in pairs(self.threads) do
		thread:update()
		if thread.idle and currentTime - thread.lastTime > self.keepAliveTime then
			thread:stop()
			self.inputObservable:remove(thread)
			self.threads[i] = nil
		end
	end
	for i, thread in pairs(self.runningThreads) do
		if not thread:isRunning() then
			self.runningThreads[i] = nil
		end
	end

	local waiting = self.waiting
	if waiting then
		self.waiting = nil
		return coroutine.resume(waiting)
	end

	local task = self.queue[1]
	if not task then
		return
	end

	local thread = self:getIdleThread()
	if thread then
		thread:execute(task)
		table.remove(self.queue, 1)
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

ThreadPool.createThread = function(self, id)
	local thread = Thread:new()

	self.inputObservable:add(thread)

	thread.pool = self
	thread.id = id
	thread:create(self.codestring:format(id))

	self.threads[id] = thread
	self.runningThreads[id] = thread

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
			local p = event.params
			local status, q, w, e, r, t, y, u, i = xpcall(
				loadstring(event.codestring),
				debug.traceback,
				p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8]
			)
			internalOutputChannel:push({status, q, w, e, r, t, y, u, i})
		end
	end
]]

return ThreadPool
