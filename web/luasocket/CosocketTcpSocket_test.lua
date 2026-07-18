local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local CosocketTcpSocket = require("web.luasocket.CosocketTcpSocket")
local table_util = require("table_util")
local socket = require("socket")

local test = {}

local FakeSocket = {}
FakeSocket.__index = FakeSocket

function FakeSocket:new()
	return setmetatable({
		connect_returns = {},
		receive_returns = {},
		send_returns = {},
		handshake_returns = {},
		receive_calls = {},
		send_calls = {},
		handshake_calls = 0,
		timeout = nil,
		closed = false,
	}, self)
end

function FakeSocket:settimeout(timeout)
	self.timeout = timeout
	return 1
end

function FakeSocket:connect(host, port)
	self.connect_host = host
	self.connect_port = port
	return table_util.unpack(table.remove(self.connect_returns, 1))
end

function FakeSocket:receive(pattern, prefix)
	table.insert(self.receive_calls, {pattern, prefix})
	return table_util.unpack(table.remove(self.receive_returns, 1))
end

function FakeSocket:send(data, i, j)
	table.insert(self.send_calls, {data, i, j})
	return table_util.unpack(table.remove(self.send_returns, 1))
end

function FakeSocket:dohandshake()
	self.handshake_calls = self.handshake_calls + 1
	return table_util.unpack(table.remove(self.handshake_returns, 1))
end

function FakeSocket:getpeername()
	return "127.0.0.1", 1234
end

function FakeSocket:close()
	self.closed = true
	return 1
end

local function new_select_mock()
	local mock = {
		ready_read = {},
		ready_write = {},
		calls = {},
	}

	local function select_func(recvt, sendt, timeout)
		table.insert(mock.calls, {
			recvt = recvt,
			sendt = sendt,
			timeout = timeout,
		})
		return mock.ready_read, mock.ready_write
	end

	return mock, select_func
end

local function new_socket()
	local mock, select_func = new_select_mock()
	local time = {0}
	local scheduler = CosocketScheduler(select_func, function()
		return time[1]
	end)
	local raw_socket = FakeSocket:new()
	local tcp_socket = CosocketTcpSocket(scheduler, nil, raw_socket)
	return tcp_socket, raw_socket, scheduler, mock, time
end

---@param t testing.T
---@param scheduler web.CosocketScheduler
---@param condition fun(): boolean
---@param step fun()?
local function pump_until(t, scheduler, condition, step)
	local deadline = socket.gettime() + 2
	while not condition() do
		if step then
			step()
		end
		local ok, err = scheduler:update(0.01)
		if not ok and err then
			error(err)
		end
		t:assert(socket.gettime() < deadline)
	end
end

---@param t testing.T
function test.connect_waits_for_write_readiness(t)
	local tcp_socket, raw_socket, scheduler, mock = new_socket()
	raw_socket.connect_returns = {
		table_util.pack(nil, "timeout"),
		{1},
	}

	local result
	local co = coroutine.create(function()
		result = {tcp_socket:connect("example.test", 1234)}
	end)

	t:tdeq({coroutine.resume(co)}, {true})
	t:eq(result, nil)
	t:eq(raw_socket.connect_host, "example.test")
	t:eq(raw_socket.connect_port, 1234)

	mock.ready_write = {raw_socket}
	t:eq(scheduler:update(), true)
	t:tdeq(result, {1})
	t:eq(mock.calls[1].sendt[1], raw_socket)
end

---@param t testing.T
function test.connect_times_out(t)
	local tcp_socket, raw_socket, scheduler, mock, time = new_socket()
	tcp_socket:settimeout(5)
	raw_socket.connect_returns = {
		table_util.pack(nil, "timeout"),
	}

	local result
	local co = coroutine.create(function()
		result = {tcp_socket:connect("example.test", 1234)}
	end)

	t:tdeq({coroutine.resume(co)}, {true})
	t:eq(result, nil)
	t:eq(scheduler:update(60), false)
	t:eq(mock.calls[1].timeout, 5)

	time[1] = 5
	t:eq(scheduler:update(60), true)
	t:tdeq(result, {nil, "timeout"})
end

---@param t testing.T
function test.receive_waits_and_preserves_partial(t)
	local tcp_socket, raw_socket, scheduler, mock = new_socket()
	raw_socket.receive_returns = {
		table_util.pack(nil, "timeout", "ab"),
		{"abcd"},
	}

	local result
	local co = coroutine.create(function()
		result = {tcp_socket:receive(4)}
	end)

	t:tdeq({coroutine.resume(co)}, {true})
	t:eq(result, nil)
	t:tdeq(raw_socket.receive_calls[1], {4, nil})

	mock.ready_read = {raw_socket}
	t:eq(scheduler:update(), true)
	t:tdeq(raw_socket.receive_calls[2], {4, "ab"})
	t:tdeq(result, {"abcd"})
end

---@param t testing.T
function test.receive_returns_closed(t)
	local tcp_socket, raw_socket = new_socket()
	raw_socket.receive_returns = {
		table_util.pack(nil, "closed", "ab"),
	}

	t:tdeq({tcp_socket:receive(4)}, {nil, "closed", "ab"})
end

---@param t testing.T
function test.receiveany_returns_available_partial(t)
	local tcp_socket, raw_socket = new_socket()
	raw_socket.receive_returns = {
		table_util.pack(nil, "timeout", "ab"),
	}

	t:tdeq({tcp_socket:receiveany(4096)}, {"ab"})
	t:tdeq(raw_socket.receive_calls[1], {4096, nil})
end

---@param t testing.T
function test.receiveany_waits_when_no_data_is_available(t)
	local tcp_socket, raw_socket, scheduler, mock = new_socket()
	raw_socket.receive_returns = {
		table_util.pack(nil, "timeout", ""),
		table_util.pack(nil, "timeout", "ab"),
	}

	local result
	local co = coroutine.create(function()
		result = {tcp_socket:receiveany(4096)}
	end)

	t:tdeq({coroutine.resume(co)}, {true})
	t:eq(result, nil)
	mock.ready_read = {raw_socket}
	t:eq(scheduler:update(), true)
	t:tdeq(result, {"ab"})
end

---@param t testing.T
function test.send_waits_and_continues_after_partial(t)
	local tcp_socket, raw_socket, scheduler, mock = new_socket()
	raw_socket.send_returns = {
		table_util.pack(nil, "timeout", 2),
		{5},
	}

	local result
	local co = coroutine.create(function()
		result = {tcp_socket:send("abcde")}
	end)

	t:tdeq({coroutine.resume(co)}, {true})
	t:eq(result, nil)
	t:tdeq(raw_socket.send_calls[1], {"abcde", 1, 5})

	mock.ready_write = {raw_socket}
	t:eq(scheduler:update(), true)
	t:tdeq(raw_socket.send_calls[2], {"abcde", 3, 5})
	t:tdeq(result, {5})
end

---@param t testing.T
function test.send_waits_for_read_on_wantread(t)
	local tcp_socket, raw_socket, scheduler, mock = new_socket()
	raw_socket.send_returns = {
		table_util.pack(nil, "wantread", 0),
		{3},
	}

	local result
	local co = coroutine.create(function()
		result = {tcp_socket:send("abc")}
	end)

	t:tdeq({coroutine.resume(co)}, {true})
	mock.ready_read = {raw_socket}
	t:eq(scheduler:update(), true)
	t:tdeq(result, {3})
	t:eq(mock.calls[1].recvt[1], raw_socket)
end

---@param t testing.T
function test.sslhandshake_waits_for_read_and_write(t)
	local tcp_socket, raw_socket, scheduler, mock = new_socket()
	raw_socket.handshake_returns = {
		table_util.pack(nil, "wantread"),
		table_util.pack(nil, "wantwrite"),
		{1},
	}

	local result
	local co = coroutine.create(function()
		result = {tcp_socket:sslhandshake()}
	end)

	t:tdeq({coroutine.resume(co)}, {true})
	t:eq(result, nil)
	t:eq(raw_socket.handshake_calls, 1)

	mock.ready_read = {raw_socket}
	t:eq(scheduler:update(), true)
	t:eq(result, nil)
	t:eq(raw_socket.handshake_calls, 2)
	t:eq(mock.calls[1].recvt[1], raw_socket)

	mock.ready_read = {}
	mock.ready_write = {raw_socket}
	t:eq(scheduler:update(), true)
	t:tdeq(result, {1})
	t:eq(raw_socket.handshake_calls, 3)
	t:eq(mock.calls[2].sendt[1], raw_socket)
end

---@param t testing.T
function test.sslhandshake_times_out(t)
	local tcp_socket, raw_socket, scheduler, mock, time = new_socket()
	tcp_socket:settimeout(5)
	raw_socket.handshake_returns = {
		table_util.pack(nil, "wantread"),
	}

	local result
	local co = coroutine.create(function()
		result = {tcp_socket:sslhandshake()}
	end)

	t:tdeq({coroutine.resume(co)}, {true})
	t:eq(result, nil)
	t:eq(scheduler:update(60), false)
	t:eq(mock.calls[1].timeout, 5)

	time[1] = 5
	t:eq(scheduler:update(60), true)
	t:tdeq(result, {nil, "timeout"})
end

---@param t testing.T
function test.sslhandshake_returns_fatal_error(t)
	local tcp_socket, raw_socket = new_socket()
	raw_socket.handshake_returns = {
		table_util.pack(nil, "certificate verify failed"),
	}

	t:tdeq({tcp_socket:sslhandshake()}, {nil, "certificate verify failed"})
end

---@param t testing.T
function test.selectreceive_and_selectsend_use_scheduler_select(t)
	local tcp_socket, raw_socket, scheduler, mock = new_socket()

	mock.ready_read = {raw_socket}
	t:eq(tcp_socket:selectreceive(0), true)
	t:eq(mock.calls[1].recvt[1], raw_socket)
	t:eq(mock.calls[1].timeout, 0)

	mock.ready_read = {}
	mock.ready_write = {raw_socket}
	t:eq(tcp_socket:selectsend(0), true)
	t:eq(mock.calls[2].sendt[1], raw_socket)
	t:eq(mock.calls[2].timeout, 0)
end

---@param t testing.T
function test.close_wakes_waiter(t)
	local tcp_socket, raw_socket, scheduler = new_socket()
	raw_socket.receive_returns = {
		table_util.pack(nil, "timeout", ""),
	}

	local result
	local co = coroutine.create(function()
		result = {tcp_socket:receive(1)}
	end)

	t:tdeq({coroutine.resume(co)}, {true})
	t:eq(result, nil)

	tcp_socket:close()

	t:eq(raw_socket.closed, true)
	t:tdeq(result, {nil, "closed", ""})
end

---@param t testing.T
function test.real_tcp_connect_send_receive(t)
	local server = assert(socket.tcp4 and socket.tcp4() or socket.tcp())
	assert(server:setoption("reuseaddr", true))
	assert(server:bind("127.0.0.1", 0))
	assert(server:listen(1))
	assert(server:settimeout(0))

	local _ip, port = server:getsockname()

	local scheduler = CosocketScheduler()
	local client = CosocketTcpSocket(scheduler, 4)

	---@type TCPSocket?
	local peer
	local function accept_peer()
		if peer then
			return
		end
		local _peer, err = server:accept()
		if _peer then
			peer = _peer
			assert(peer:settimeout(0))
		elseif err ~= "timeout" then
			error(err)
		end
	end

	local connect_result
	local connect_co = coroutine.create(function()
		connect_result = {client:connect("127.0.0.1", port)}
	end)
	t:tdeq({coroutine.resume(connect_co)}, {true})

	pump_until(t, scheduler, function()
		return connect_result ~= nil and peer ~= nil
	end, accept_peer)

	t:tdeq(connect_result, {1})
	t:assert(peer)

	local send_result
	local send_co = coroutine.create(function()
		send_result = {client:send("hello")}
	end)
	t:tdeq({coroutine.resume(send_co)}, {true})

	pump_until(t, scheduler, function()
		return send_result ~= nil
	end)

	t:tdeq(send_result, {5})

	local server_data
	pump_until(t, scheduler, function()
		local data, err = peer:receive(5)
		if data then
			server_data = data
			return true
		elseif err == "timeout" then
			return false
		end
		error(err)
	end)
	t:eq(server_data, "hello")

	local receive_result
	local receive_co = coroutine.create(function()
		receive_result = {client:receive(5)}
	end)
	t:tdeq({coroutine.resume(receive_co)}, {true})

	assert(peer:send("world"))

	pump_until(t, scheduler, function()
		return receive_result ~= nil
	end)

	t:tdeq(receive_result, {"world"})

	client:close()
	peer:close()
	server:close()
end

return test
