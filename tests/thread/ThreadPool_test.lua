local ThreadPool = require("thread.ThreadPool")

local test = {}

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
	local old_loaded = ThreadPool.loaded
	ThreadPool.managedThreads = {}
	ThreadPool.threads = {}
	ThreadPool.queue = {}
	ThreadPool.loaded = true

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
	ThreadPool.runningThreads = {
		[1] = {
			task = {
				name = "test task",
			},
			isRunning = function()
				return true
			end,
		},
	}

	t:tdeq(ThreadPool:getRunningThreadNames(), {"thread pool worker 1: test task"})

	ThreadPool.managedThreads = old_managed_threads
	ThreadPool.runningThreads = old_running_threads
end

return test
