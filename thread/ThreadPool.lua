local Thread = require("thread.Thread")
local synctable = require("synctable")

local ThreadPool = {}

ThreadPool.poolSize = 4
ThreadPool.keepAliveTime = 1

ThreadPool.threads = {}
ThreadPool.runningThreads = {}
ThreadPool.queue = {}
ThreadPool.loaded = true

local _synctable = {}
ThreadPool.synctable = synctable.new(_synctable, function(...)
	-- print("send", synctable.format("main", ...))
	for _, thread in pairs(ThreadPool.threads) do
		if thread ~= ThreadPool.ignoreSyncThread then
			thread:receive({...})
		end
	end
end)

function ThreadPool:execute(task)
	if not self.loaded then
		return
	end
	self.queue[#self.queue + 1] = task
	return self:update()
end

function ThreadPool:isRunning()
	return next(self.runningThreads) ~= nil
end

function ThreadPool:waitAsync()
	assert(not self.loaded, "attempt to waitAsync when ThreadPool is loaded")
	assert(not self.waiting, "attempt to waitAsync while waitingAsync")
	if not self:isRunning() then
		return
	end
	self.waiting = coroutine.running()
	coroutine.yield()
end

function ThreadPool:unload()
	self.queue = {}
	for _, thread in pairs(self.threads) do
		thread:stop()
	end
	self.loaded = false
end

function ThreadPool:update()
	local currentTime = love.timer.getTime()

	for i, thread in pairs(self.threads) do
		thread:update()
		if thread.idle and currentTime - thread.lastTime > self.keepAliveTime then
			thread:stop()
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

function ThreadPool:getIdleThread()
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

function ThreadPool:createThread(id)
	local thread = Thread()

	thread.pool = self
	thread.id = id

	if not self.codestring then
		local path = "aqua/thread/threadcode.lua"
		self.codestring = love.filesystem.read(path)
	end
	thread:create(self.codestring:gsub('"<threadId>"', id))

	synctable.new(_synctable, function(...)
		thread:receive({...})
	end)

	self.threads[id] = thread
	self.runningThreads[id] = thread

	return thread
end

return ThreadPool
