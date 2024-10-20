local StringSocket = require("web.socket.StringSocket")

local test = {}

---@param t testing.T
function test.receive_exact(t)
	local soc = StringSocket()

	t:tdeq({soc:send("qwe")}, {3})

	t:tdeq({soc:receive(3)}, {"qwe"})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})

	soc:close()

	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_more_closed(t)
	local soc = StringSocket()

	t:tdeq({soc:send("qwe")}, {3})

	soc:close()

	t:tdeq({soc:receive(4)}, {nil, "closed", "qwe"})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_more_timeout(t)
	local soc = StringSocket()

	t:tdeq({soc:send("qwe")}, {3})

	t:tdeq({soc:receive(4)}, {nil, "timeout", "qwe"})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})

	soc:close()

	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
function test.send_limited_closed(t)
	local soc = StringSocket(nil, 4)

	t:tdeq({soc:send("qwe")}, {3})

	soc:close()

	t:tdeq({soc:send("rty")}, {nil, "closed", 0})

	t:tdeq({soc:receive(100)}, {nil, "closed", "qwe"})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
function test.send_limited_exact(t)
	local soc = StringSocket(nil, 6)

	t:tdeq({soc:send("qwerty")}, {6})

	t:tdeq({soc:receive(100)}, {nil, "timeout", "qwerty"})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})
end

---@param t testing.T
function test.send_limited_more(t)
	local soc = StringSocket(nil, 4)

	t:tdeq({soc:send("qwerty")}, {nil, "timeout", 4})

	t:tdeq({soc:receive(100)}, {nil, "timeout", "qwer"})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})
	t:tdeq({soc:receive(100)}, {nil, "timeout", ""})
end

return test
