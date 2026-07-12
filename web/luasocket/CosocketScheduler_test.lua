local CosocketScheduler = require("web.luasocket.CosocketScheduler")

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
