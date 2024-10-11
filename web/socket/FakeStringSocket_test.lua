local FakeStringSocket = require("web.socket.FakeStringSocket")

local test = {}

---@param t testing.T
function test.receive_size_exact(t)
	local soc = FakeStringSocket()

	soc:send("qwe")

	t:tdeq({soc:receive(3)}, {"qwe"})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})

	soc:close()

	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_size_more_closed(t)
	local soc = FakeStringSocket()

	soc:send("qwe")
	soc:close()

	t:tdeq({soc:receive(4)}, {nil, "closed", "qwe"})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_size_more_timeout(t)
	local soc = FakeStringSocket()

	soc:send("qwe")

	t:tdeq({soc:receive(4)}, {nil, "timeout", "qwe"})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})

	soc:close()

	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_prefix(t)
	local soc = FakeStringSocket()

	soc:send("qwerty")

	t:tdeq({soc:receive(2, "asd")}, {"asd"})
	t:tdeq({soc:receive(3, "asd")}, {"asd"})
	t:tdeq({soc:receive(4, "asd")}, {"asdq"})
	t:tdeq({soc:receive(5, "asd")}, {"asdwe"})

	soc:close()
end

---@param t testing.T
function test.send_size_closed(t)
	local soc = FakeStringSocket(nil, 6)

	t:tdeq({soc:send("qwerty", 1, 2)}, {2})

	soc:close()

	t:tdeq({soc:send("qwerty", 3, 4)}, {nil, "closed", 0})

	t:tdeq({soc:receive(100)}, {nil, "closed", "qw"})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
function test.send_size_exact(t)
	local soc = FakeStringSocket(nil, 6)

	t:tdeq({soc:send("qwerty", 1, 2)}, {2})
	t:tdeq({soc:send("qwerty", 3, 4)}, {4})
	t:tdeq({soc:send("qwerty", 5, 6)}, {6})

	t:tdeq({soc:receive(100)}, {nil, "timeout", "qwerty"})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})
end

---@param t testing.T
function test.send_size_more(t)
	local soc = FakeStringSocket(nil, 4)

	t:tdeq({soc:send("qwerty", 1, 2)}, {2})
	t:tdeq({soc:send("qwerty", 3, 6)}, {nil, "timeout", 4})

	t:tdeq({soc:receive(100)}, {nil, "timeout", "qwer"})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})
end

return test
