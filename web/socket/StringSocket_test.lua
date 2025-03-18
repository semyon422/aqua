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
function test.receive_yielding(t)
	local soc = StringSocket()
	soc.yielding = true

	t:tdeq({soc:send("qwe")}, {3})

	local state = 0
	local co = coroutine.create(function()
		t:tdeq({soc:receive(1)}, {"q"})
		state = 1
		t:tdeq({soc:receive(5)}, {"werty"})
		state = 2
	end)

	coroutine.resume(co)
	t:eq(state, 1)
	coroutine.resume(co)
	t:eq(state, 1)

	t:tdeq({soc:send("rty")}, {3})

	coroutine.resume(co)
	t:eq(state, 2)
end

--------------------------------------------------------------------------------

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

---@param t testing.T
function test.send_yielding(t)
	local soc = StringSocket(nil, 4, true)

	local state = 0
	local co = coroutine.create(function()
		t:tdeq({soc:send("qwe")}, {3})
		state = 1
		t:tdeq({soc:send("rty")}, {3})
		state = 2
	end)

	coroutine.resume(co)
	t:eq(state, 1)
	coroutine.resume(co)
	t:eq(state, 1)

	t:tdeq({soc:receive(3)}, {"qwe"})

	coroutine.resume(co)
	t:eq(state, 2)
end

---@param t testing.T
function test.split(t)
	local soc_1 = StringSocket()
	local soc_2 = soc_1:split()

	t:tdeq({soc_1:send("req")}, {3})
	t:tdeq({soc_1:receive(3)}, {nil, "timeout", ""})

	t:tdeq({soc_2:receive(3)}, {"req"})
	t:tdeq({soc_2:send("res")}, {3})

	t:tdeq({soc_1:receive(3)}, {"res"})
end

return test
