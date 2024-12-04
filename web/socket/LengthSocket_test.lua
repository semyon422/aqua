local LengthSocket = require("web.socket.LengthSocket")
local StringSocket = require("web.socket.StringSocket")

local test = {}

---@param t testing.T
function test.receive(t)
	local str_soc = StringSocket("qwertyuiop")
	local soc = LengthSocket(str_soc, 6)

	t:tdeq({soc:receive(2)}, {"qw"})
	t:tdeq({soc:receive(10)}, {nil, "closed", "erty"})
	t:tdeq({soc:receive(10)}, {nil, "closed", ""})
	t:tdeq({soc:receive(10)}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_timeout(t)
	local str_soc = StringSocket("qw")
	local soc = LengthSocket(str_soc, 10)

	t:tdeq({soc:receive(10)}, {nil, "timeout", "qw"})
	t:tdeq({soc:receive(10)}, {nil, "timeout", ""})
	t:tdeq({soc:receive(10)}, {nil, "timeout", ""})

	str_soc:send("ertyuiop")

	t:tdeq({soc:receive(8)}, {"ertyuiop"})
	t:tdeq({soc:receive(8)}, {nil, "closed", ""})
	t:tdeq({soc:receive(8)}, {nil, "closed", ""})
end

---@param t testing.T
function test.send(t)
	local str_soc = StringSocket()
	local soc = LengthSocket(str_soc, 6)

	t:tdeq({soc:send("qwertyuiop", 2, 3)}, {3})
	t:eq(str_soc.remainder, "we")
	t:eq(soc.length, 4)

	t:tdeq({soc:send("qwertyuiop", 5, 10)}, {nil, "closed", 8})
	t:eq(str_soc.remainder, "wetyui")
	t:eq(soc.length, 0)

	t:tdeq({soc:send("qwertyuiop", 3, 8)}, {nil, "closed", 2})
	t:tdeq({soc:send("qwertyuiop", 3, 8)}, {nil, "closed", 2})
end

---@param t testing.T
function test.send_exact(t)
	local str_soc = StringSocket()
	local soc = LengthSocket(str_soc, 6)

	t:tdeq({soc:send("qwerty")}, {6})
	t:tdeq({soc:send("qwerty")}, {nil, "closed", 0})
end

---@param t testing.T
function test.send_timeout(t)
	local str_soc = StringSocket("", 6)
	local soc = LengthSocket(str_soc, 10)

	t:tdeq({soc:send("qwertyuiop")}, {nil, "timeout", 6})
	t:tdeq({soc:send("qwertyuiop")}, {nil, "timeout", 0})
end

return test
