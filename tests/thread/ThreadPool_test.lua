local thread = require("thread")
local ThreadPool = require("thread.ThreadPool")

local test = {}

---@param t testing.T
function test.async_result_is_deferred_until_after_yield(t)
	local old_queue = ThreadPool.queue
	local old_loaded = ThreadPool.loaded
	local old_update = ThreadPool.update
	ThreadPool.queue = {}
	ThreadPool.loaded = true

	local updated = false
	ThreadPool.update = function(self)
		updated = true
		local task = table.remove(self.queue, 1)
		if task then
			task.result(42)
		end
	end

	local ok, err = xpcall(function()
		local result
		local async = thread.async(function()
			return 42
		end)
		local coroutine_ = coroutine.create(function()
			result = async()
		end)

		local resumed, resume_error = coroutine.resume(coroutine_)
		t:eq(resumed, true, resume_error)
		t:eq(updated, false)
		t:eq(coroutine.status(coroutine_), "suspended")
		t:eq(#ThreadPool.queue, 1)

		ThreadPool:update()

		t:eq(updated, true)
		t:eq(result, 42)
		t:eq(coroutine.status(coroutine_), "dead")
		t:eq(#ThreadPool.queue, 0)
	end, debug.traceback)

	ThreadPool.queue = old_queue
	ThreadPool.loaded = old_loaded
	ThreadPool.update = old_update

	assert(ok, err)
end

---@param t testing.T
function test.execute_only_queues_task(t)
	local old_queue = ThreadPool.queue
	local old_loaded = ThreadPool.loaded
	local old_update = ThreadPool.update
	ThreadPool.queue = {}
	ThreadPool.loaded = true

	local updated = false
	ThreadPool.update = function()
		updated = true
	end

	local task = {
		f = "",
		args = {},
		result = function() end,
		trace = "",
		name = "test task",
	}
	ThreadPool:execute(task)

	t:eq(updated, false)
	t:eq(#ThreadPool.queue, 1)
	t:eq(ThreadPool.queue[1], task)

	ThreadPool.queue = old_queue
	ThreadPool.loaded = old_loaded
	ThreadPool.update = old_update
end

---@param t testing.T
function test.managed_thread_names(t)
	local old_managed_threads = ThreadPool.managedThreads
	local old_running_threads = ThreadPool.runningThreads
	ThreadPool.managedThreads = {}
	ThreadPool.runningThreads = {}

	local running = true
	local managed_thread = {
		isRunning = function()
			return running
		end,
	}

	ThreadPool:registerManagedThread("test", "managed test thread", managed_thread)

	t:eq(ThreadPool:isRunning(), true)
	t:tdeq(ThreadPool:getRunningThreadNames(), {"managed test thread"})

	running = false

	t:eq(ThreadPool:isRunning(), false)
	t:tdeq(ThreadPool:getRunningThreadNames(), {})
	t:eq(ThreadPool.managedThreads.test, nil)

	ThreadPool.managedThreads = old_managed_threads
	ThreadPool.runningThreads = old_running_threads
end

---@param t testing.T
function test.unload_stops_marked_managed_threads(t)
	local old_managed_threads = ThreadPool.managedThreads
	local old_threads = ThreadPool.threads
	local old_queue = ThreadPool.queue
	---@type boolean
	local old_loaded = ThreadPool.loaded
	ThreadPool.managedThreads = {}
	ThreadPool.threads = {}
	ThreadPool.queue = {}
	ThreadPool.loaded = true

	---@type boolean
	local stopped = false
	local managed_thread = {
		isRunning = function()
			return not stopped
		end,
		stop = function()
			stopped = true
		end,
	}

	ThreadPool:registerManagedThread("test", "managed test thread", managed_thread, true)
	ThreadPool:unload()

	t:eq(stopped, true)
	t:eq(ThreadPool.loaded, false)

	ThreadPool.managedThreads = old_managed_threads
	ThreadPool.threads = old_threads
	ThreadPool.queue = old_queue
	ThreadPool.loaded = old_loaded
end

---@param t testing.T
function test.running_worker_names_include_task_name(t)
	local old_managed_threads = ThreadPool.managedThreads
	local old_running_threads = ThreadPool.runningThreads
	ThreadPool.managedThreads = {}
	---@type thread.Thread
	local worker = {
		task = {
			f = "",
			args = {},
			result = function() end,
			trace = "",
			name = "test task",
		},
		isRunning = function()
			return true
		end,
	} --[[@as any]]
	ThreadPool.runningThreads = {[1] = worker}

	t:tdeq(ThreadPool:getRunningThreadNames(), {"thread pool worker 1: test task"})

	ThreadPool.managedThreads = old_managed_threads
	ThreadPool.runningThreads = old_running_threads
end

return test
