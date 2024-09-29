local Thread = require("thread.Thread")
local synctable = require("synctable")

local ThreadPool = {}

ThreadPool.poolSize = love.system.getProcessorCount()
ThreadPool.keepAliveTime = 10

ThreadPool.threads = {}
ThreadPool.runningThreads = {}
ThreadPool.queue = {}
ThreadPool.loaded = true

ThreadPool.initFunc = string.dump(function() end)
ThreadPool.initArgsFunc = function() return {} end

local _synctable = {}
ThreadPool.synctable = synctable.new(_synctable, function(...)
	for _, thread in pairs(ThreadPool.threads) do
		thread:sync(...)
	end
end)

---@param task table
function ThreadPool:execute(task)
	if not self.loaded then
		return
	end
	table.insert(self.queue, task)
	self:update()
end

---@param f function
---@param argsf function?
function ThreadPool:setInitFunc(f, argsf)
	self.initFunc = string.dump(f)
	self.initArgsFunc = argsf or self.initArgsFunc
end

---@return boolean
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
		thread:pushStop()
	end
	self.loaded = false
end

function ThreadPool:update()
	local currentTime = love.timer.getTime()

	for i, thread in pairs(self.threads) do
		thread:update()
		if not thread.idle then
			thread:updateLastTime(love.timer.getTime())
		end
		if thread.idle and currentTime - thread.lastTime > self.keepAliveTime then
			thread:pushStop()
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
		coroutine.resume(waiting)
		return
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

---@return thread.Thread?
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

---@param id number
---@return thread.Thread
function ThreadPool:createThread(id)
	local thread = Thread(id, ThreadPool.synctable)

	-- populate new thread with shared data
	synctable.new(_synctable, function(...)
		thread:sync(...)
	end)

	self.threads[id] = thread
	self.runningThreads[id] = thread

	thread:start(self.initFunc, self.initArgsFunc())

	return thread
end

return ThreadPool
