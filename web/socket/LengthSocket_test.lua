local LengthSocket = require("web.socket.LengthSocket")
local RangeSocket = require("web.socket.RangeSocket")
local StringSocket = require("web.socket.StringSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")

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
function test.receive_early_close(t)
	local str_soc = StringSocket()

	str_soc:send("qwe")
	str_soc:close()

	local soc = LengthSocket(str_soc, 10)

	t:tdeq({soc:receive(20)}, {nil, "closed early", "qwe"})
	t:tdeq({soc:receive(20)}, {nil, "closed early", ""})
	t:tdeq({soc:receive(20)}, {nil, "closed early", ""})
end

---@param t testing.T
function test.receive_early_close_ex(t)
	local str_soc = StringSocket()

	str_soc:send("qwe")
	str_soc:close()

	local soc = ExtendedSocket(LengthSocket(str_soc, 10))

	t:tdeq({soc:receive("*a")}, {nil, "closed early", "qwe"})
	t:tdeq({soc:receive("*a")}, {nil, "closed early", ""})
	t:tdeq({soc:receive("*a")}, {nil, "closed early", ""})
end

---@param t testing.T
function test.send(t)
	local str_soc = StringSocket()
	local len_soc = LengthSocket(str_soc, 6)
	local soc = RangeSocket(len_soc)

	t:tdeq({soc:send("qwertyuiop", 2, 3)}, {3})
	t:eq(str_soc.remainder, "we")
	t:eq(len_soc.length, 4)

	t:tdeq({soc:send("qwertyuiop", 5, 10)}, {nil, "closed", 8})
	t:eq(str_soc.remainder, "wetyui")
	t:eq(len_soc.length, 0)

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

---@param t testing.T
function test.receiveany_basic(t)
	local str_soc = StringSocket("hello world")
	local soc = LengthSocket(str_soc, 5)

	t:tdeq({soc:receiveany(10)}, {"hello"})
	t:tdeq({soc:receiveany(10)}, {nil, "closed"})
end

---@param t testing.T
function test.receiveany_respects_max(t)
	local str_soc = StringSocket("hello world")
	local soc = LengthSocket(str_soc, 10)

	t:tdeq({soc:receiveany(3)}, {"hel"})
	t:tdeq({soc:receiveany(3)}, {"lo "})
	t:tdeq({soc:receiveany(3)}, {"wor"})
end

---@param t testing.T
function test.receiveany_timeout(t)
	local str_soc = StringSocket()
	local soc = LengthSocket(str_soc, 10)

	t:tdeq({soc:receiveany(10)}, {nil, "timeout"})
	t:eq(soc.length, 10)

	str_soc:send("ab")
	t:tdeq({soc:receiveany(10)}, {"ab"})
	t:eq(soc.length, 8)
end

---@param t testing.T
function test.receiveany_closed(t)
	local str_soc = StringSocket("hello world")
	local soc = LengthSocket(str_soc, 5)

	t:tdeq({soc:receiveany(5)}, {"hello"})
	t:tdeq({soc:receiveany(5)}, {nil, "closed"})
	t:tdeq({soc:receiveany(5)}, {nil, "closed"})
end

---@param t testing.T
function test.receiveany_mixed_with_receive(t)
	local str_soc = StringSocket("hello world")
	local soc = LengthSocket(str_soc, 10)

	t:tdeq({soc:receiveany(3)}, {"hel"})
	t:tdeq({soc:receive(2)}, {"lo"})
	t:tdeq({soc:receiveany(10)}, {" worl"})
	t:tdeq({soc:receiveany(10)}, {nil, "closed"})
end

return test
