local Thread = require("thread.Thread")
local synctable = require("synctable")

local ThreadPool = {}

---@class thread.Task
---@field f function|string
---@field args table
---@field result function
---@field trace string
---@field name string

---@class thread.ManagedThread
---@field name string
---@field thread {isRunning: fun(self: any): boolean, stop: fun(self: any)?}
---@field stop_with_pool boolean

local function getLoveTimerNow()
	if love and love.timer and love.timer.getTime then
		return love.timer.getTime
	end
	return os.clock
end

local function getProcessorCount()
	if love and love.system and love.system.getProcessorCount then
		return love.system.getProcessorCount()
	end
	return 1
end

ThreadPool.poolSize = getProcessorCount()
ThreadPool.keepAliveTime = 10

---@type {[integer]: thread.Thread}
ThreadPool.threads = {}
---@type {[integer]: thread.Thread}
ThreadPool.runningThreads = {}
---@type {[any]: thread.ManagedThread}
ThreadPool.managedThreads = {}
---@type thread.Task[]
ThreadPool.queue = {}
ThreadPool.loaded = true
ThreadPool.lastThreadId = 0

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
	if next(self.runningThreads) ~= nil then
		return true
	end
	for _, managed in pairs(self.managedThreads) do
		if managed.thread:isRunning() then
			return true
		end
	end
	return false
end

---@param id any
---@param name string
---@param managed_thread thread.ManagedThread.thread
---@param stop_with_pool boolean?
function ThreadPool:registerManagedThread(id, name, managed_thread, stop_with_pool)
	self.managedThreads[id] = {
		name = name,
		thread = managed_thread,
		stop_with_pool = stop_with_pool == true,
	}
end

---@param id any
function ThreadPool:unregisterManagedThread(id)
	self.managedThreads[id] = nil
end

---@return string[]
function ThreadPool:getRunningThreadNames()
	---@type string[]
	local names = {}
	for i, thread in pairs(self.runningThreads) do
		if thread:isRunning() then
			local task_name = thread.task and thread.task.name
			table.insert(names, "thread pool worker " .. tostring(i) .. ": " .. tostring(task_name or "idle"))
		end
	end
	for id, managed in pairs(self.managedThreads) do
		if managed.thread:isRunning() then
			table.insert(names, managed.name)
		else
			self.managedThreads[id] = nil
		end
	end
	return names
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
	for _, managed in pairs(self.managedThreads) do
		if managed.stop_with_pool and managed.thread.stop then
			managed.thread:stop()
		end
	end
	self.loaded = false
end

function ThreadPool:stopThreads()
	for i, thread in pairs(self.threads) do
		thread:pushStop()
		self.threads[i] = nil
	end
end

function ThreadPool:update()
	local now = getLoveTimerNow()
	local currentTime = now()

	for i, thread in pairs(self.threads) do
		thread:update()
		if not thread.idle then
			thread:updateLastTime(now())
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
	for id, managed in pairs(self.managedThreads) do
		if not managed.thread:isRunning() then
			self.managedThreads[id] = nil
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
	local _id = self.lastThreadId + 1
	self.lastThreadId = _id
	local thread = Thread(_id, ThreadPool.synctable)

	-- populate new thread with shared data
	synctable.new(_synctable, function(...)
		thread:sync(...)
	end)

	self.threads[id] = thread
	self.runningThreads[id] = thread

	thread:start()
	thread:init(self.initFunc, self.initArgsFunc())

	return thread
end

return ThreadPool
