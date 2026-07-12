local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local coext = require("coext")

local test = {}

local function new_select_mock()
	local mock = {
		ready_read = {},
		ready_write = {},
		err = nil,
		calls = {},
	}

	local function select_func(recvt, sendt, timeout)
		table.insert(mock.calls, {
			recvt = recvt,
			sendt = sendt,
			timeout = timeout,
		})
		return mock.ready_read, mock.ready_write, mock.err
	end

	return mock, select_func
end

---@param f fun()
local function with_coext_export(f)
	local saved = {
		resume = coroutine.resume,
		yield = coroutine.yield,
		create = coroutine.create,
		wrap = coroutine.wrap,
		newyield = coroutine.newyield,
		yieldto = coroutine.yieldto,
	}
	coext.export()
	local ok, err = pcall(f)
	coroutine.resume = saved.resume
	coroutine.yield = saved.yield
	coroutine.create = saved.create
	coroutine.wrap = saved.wrap
	coroutine.newyield = saved.newyield
	coroutine.yieldto = saved.yieldto
	if not ok then
		error(err, 0)
	end
end

---@param t testing.T
function test.wait_read_wakes_on_select(t)
	local mock, select_func = new_select_mock()
	local scheduler = CosocketScheduler(select_func, function()
		return 0
	end)

	local soc = {}
	local result
	local co = coroutine.create(function()
		result = {scheduler:waitRead(soc)}
	end)

	t:tdeq({coroutine.resume(co)}, {true})
	t:eq(result, nil)

	t:eq(scheduler:update(), false)
	t:eq(#mock.calls, 1)
	t:eq(mock.calls[1].recvt[1], soc)
	t:eq(mock.calls[1].sendt[1], nil)
	t:eq(mock.calls[1].timeout, 0)
	t:eq(result, nil)

	mock.ready_read = {soc}
	t:eq(scheduler:update(), true)
	t:tdeq(result, {true})
end

---@param t testing.T
function test.wait_write_wakes_on_select(t)
	local mock, select_func = new_select_mock()
	local scheduler = CosocketScheduler(select_func, function()
		return 0
	end)

	local soc = {}
	local result
	local co = coroutine.create(function()
		result = {scheduler:waitWrite(soc)}
	end)

	t:tdeq({coroutine.resume(co)}, {true})
	mock.ready_write = {soc}

	t:eq(scheduler:update(), true)
	t:eq(mock.calls[1].recvt[1], nil)
	t:eq(mock.calls[1].sendt[1], soc)
	t:tdeq(result, {true})
end

---@param t testing.T
function test.timeout_uses_nearest_timer(t)
	local mock, select_func = new_select_mock()
	local now = 10
	local scheduler = CosocketScheduler(select_func, function()
		return now
	end)

	local soc = {}
	local result
	local co = coroutine.create(function()
		result = {scheduler:waitRead(soc, 5)}
	end)

	t:tdeq({coroutine.resume(co)}, {true})

	t:eq(scheduler:update(60), false)
	t:eq(mock.calls[1].timeout, 5)
	t:eq(result, nil)

	now = 15
	t:eq(scheduler:update(60), true)
	t:tdeq(result, {nil, "timeout"})
	t:eq(#mock.calls, 1)
end

---@param t testing.T
function test.sleep_wakes_from_timer(t)
	local mock, select_func = new_select_mock()
	local now = 0
	local scheduler = CosocketScheduler(select_func, function()
		return now
	end)

	local result
	local co = coroutine.create(function()
		result = {scheduler:sleep(2)}
	end)

	t:tdeq({coroutine.resume(co)}, {true})
	t:eq(scheduler:update(), false)
	t:eq(#mock.calls, 0)
	t:eq(result, nil)

	now = 2
	t:eq(scheduler:update(), true)
	t:tdeq(result, {true})
end

---@param t testing.T
function test.close_socket_wakes_read_and_write_waiters(t)
	local mock, select_func = new_select_mock()
	local scheduler = CosocketScheduler(select_func, function()
		return 0
	end)

	local soc = {}
	local read_result
	local write_result

	local read_co = coroutine.create(function()
		read_result = {scheduler:waitRead(soc)}
	end)
	local write_co = coroutine.create(function()
		write_result = {scheduler:waitWrite(soc)}
	end)

	t:tdeq({coroutine.resume(read_co)}, {true})
	t:tdeq({coroutine.resume(write_co)}, {true})

	scheduler:closeSocket(soc)

	t:tdeq(read_result, {nil, "closed"})
	t:tdeq(write_result, {nil, "closed"})
	t:eq(scheduler:update(), false)
	t:eq(#mock.calls, 0)
end

---@param t testing.T
function test.cancel_wakes_waiter(t)
	local mock, select_func = new_select_mock()
	local scheduler = CosocketScheduler(select_func, function()
		return 0
	end)

	local soc = {}
	local result
	local co = coroutine.create(function()
		result = {scheduler:waitRead(soc)}
	end)

	t:tdeq({coroutine.resume(co)}, {true})
	scheduler:cancel(co, "stopped")

	t:tdeq(result, {nil, "stopped"})
	t:eq(scheduler:update(), false)
	t:eq(#mock.calls, 0)
end

---@param t testing.T
function test.multiple_waiters_resume_one_per_ready_event(t)
	local mock, select_func = new_select_mock()
	local scheduler = CosocketScheduler(select_func, function()
		return 0
	end)

	local soc = {}
	local results = {}
	for i = 1, 2 do
		local co = coroutine.create(function()
			results[i] = {scheduler:waitRead(soc)}
		end)
		t:tdeq({coroutine.resume(co)}, {true})
	end

	mock.ready_read = {soc}
	t:eq(scheduler:update(), true)
	t:tdeq(results[1], {true})
	t:eq(results[2], nil)

	t:eq(scheduler:update(), true)
	t:tdeq(results[2], {true})
end

---@param t testing.T
function test.coroutine_can_wait_again_after_resume(t)
	local mock, select_func = new_select_mock()
	local scheduler = CosocketScheduler(select_func, function()
		return 0
	end)

	local read_soc = {}
	local write_soc = {}
	local result
	local co = coroutine.create(function()
		local read_ok = scheduler:waitRead(read_soc)
		local write_ok = scheduler:waitWrite(write_soc)
		result = {read_ok, write_ok}
	end)

	t:tdeq({coroutine.resume(co)}, {true})

	mock.ready_read = {read_soc}
	mock.ready_write = {}
	t:eq(scheduler:update(), true)
	t:eq(result, nil)

	mock.ready_read = {}
	mock.ready_write = {write_soc}
	t:eq(scheduler:update(), true)
	t:tdeq(result, {true, true})
end

---@param t testing.T
function test.coroutine_wrap_iterator_can_wait_in_scheduler(t)
	local mock, select_func = new_select_mock()
	local now = 0
	local scheduler = CosocketScheduler(select_func, function()
		return now
	end)

	with_coext_export(function()
		local values = {}
		local result
		local co = coroutine.create(function()
			local iter = coroutine.wrap(function()
				coroutine.yield("before")
				local ok, err = scheduler:sleep(1)
				coroutine.yield(ok and "after" or err)
			end)

			for value in iter do
				table.insert(values, value)
			end
			result = "done"
		end)

		t:tdeq({coroutine.resume(co)}, {true})
		t:tdeq(values, {"before"})
		t:eq(result, nil)
		t:eq(coroutine.status(co), "suspended")
		t:eq(next(scheduler.waiters) ~= nil, true)
		t:eq(#mock.calls, 0)

		now = 1
		t:eq(scheduler:update(), true)
		t:tdeq(values, {"before", "after"})
		t:eq(result, "done")
		t:eq(coroutine.status(co), "dead")
		t:eq(next(scheduler.waiters), nil)
	end)
end

---@param t testing.T
function test.coroutine_create_iterator_can_wait_in_scheduler(t)
	local mock, select_func = new_select_mock()
	local now = 0
	local scheduler = CosocketScheduler(select_func, function()
		return now
	end)

	with_coext_export(function()
		local values = {}
		local result
		local co = coroutine.create(function()
			local iter_co = coroutine.create(function()
				coroutine.yield("before")
				local ok, err = scheduler:sleep(1)
				coroutine.yield(ok and "after" or err)
			end)

			local function iter()
				local ok, value = coroutine.resume(iter_co)
				if not ok then
					error(value, 0)
				end
				return value
			end

			for value in iter do
				table.insert(values, value)
			end
			result = "done"
		end)

		t:tdeq({coroutine.resume(co)}, {true})
		t:tdeq(values, {"before"})
		t:eq(result, nil)
		t:eq(coroutine.status(co), "suspended")
		t:eq(next(scheduler.waiters) ~= nil, true)

		now = 1
		t:eq(scheduler:update(), true)
		t:tdeq(values, {"before", "after"})
		t:eq(result, "done")
		t:eq(coroutine.status(co), "dead")
		t:eq(next(scheduler.waiters), nil)
	end)
end

---@param t testing.T
function test.nested_coroutine_iterators_can_wait_in_scheduler(t)
	local mock, select_func = new_select_mock()
	local now = 0
	local scheduler = CosocketScheduler(select_func, function()
		return now
	end)

	with_coext_export(function()
		local values = {}
		local result
		local co = coroutine.create(function()
			local outer_iter = coroutine.wrap(function()
				local middle_iter = coroutine.wrap(function()
					local inner_iter = coroutine.wrap(function()
						coroutine.yield("before")
						local ok, err = scheduler:sleep(1)
						coroutine.yield(ok and "after" or err)
					end)

					for value in inner_iter do
						coroutine.yield(value)
					end
				end)

				for value in middle_iter do
					coroutine.yield(value)
				end
			end)

			for value in outer_iter do
				table.insert(values, value)
			end
			result = "done"
		end)

		t:tdeq({coroutine.resume(co)}, {true})
		t:tdeq(values, {"before"})
		t:eq(result, nil)
		t:eq(coroutine.status(co), "suspended")
		t:eq(next(scheduler.waiters) ~= nil, true)

		now = 1
		t:eq(scheduler:update(), true)
		t:tdeq(values, {"before", "after"})
		t:eq(result, "done")
		t:eq(coroutine.status(co), "dead")
		t:eq(next(scheduler.waiters), nil)
	end)
end

---@param t testing.T
function test.detached_background_coroutine_waits_on_itself(t)
	local mock, select_func = new_select_mock()
	local scheduler = CosocketScheduler(select_func, function()
		return 0
	end)

	with_coext_export(function()
		local soc = {}
		local child
		local child_result
		local parent = coroutine.create(function()
			child = coext.detach(coroutine.create(function()
				child_result = {scheduler:waitRead(soc)}
			end))
			t:tdeq({coroutine.resume(child)}, {true})
		end)

		t:tdeq({coroutine.resume(parent)}, {true})
		t:eq(coroutine.status(parent), "dead")
		t:eq(coroutine.status(child), "suspended")
		t:eq(scheduler.waiters[child] ~= nil, true)
		t:eq(next(scheduler.waiters) == child, true)

		mock.ready_read = {soc}
		t:eq(scheduler:update(), true)
		t:tdeq(child_result, {true})
		t:eq(coroutine.status(child), "dead")
		t:eq(next(scheduler.waiters), nil)
	end)
end

---@param t testing.T
function test.select_error_is_returned(t)
	local mock, select_func = new_select_mock()
	local scheduler = CosocketScheduler(select_func, function()
		return 0
	end)

	local soc = {}
	local co = coroutine.create(function()
		scheduler:waitRead(soc)
	end)

	t:tdeq({coroutine.resume(co)}, {true})
	mock.err = "bad select"

	t:tdeq({scheduler:update()}, {nil, "bad select"})
end

return test
