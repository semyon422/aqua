local LineAllDecorator = require("web.socket.LineAllDecorator")
local FakeSocket = require("web.socket.FakeSocket")

local test = {}

---@param t testing.T
function test.receive_size_exact(t)
	local soc = LineAllDecorator(FakeSocket({
		{"qwe", "closed"},
	}))
	t:tdeq({soc:receive(3)}, {"qwe"})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_size_more(t)
	local soc = LineAllDecorator(FakeSocket({
		{"qwe", "closed"},
	}))
	t:tdeq({soc:receive(4)}, {nil, "closed", "qwe"})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_size_exact_timeout(t)
	local soc = LineAllDecorator(FakeSocket({
		{"qwe", "timeout"},
		{"rty", "closed"},
	}))
	t:tdeq({soc:receive(4)}, {nil, "timeout", "qwe"})
	t:tdeq({soc:receive(3)}, {"rty"})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_line(t)
	local soc = LineAllDecorator(FakeSocket({
		{"qw\re\r\nr\rty"},
		{"asd\r\nfgh", "closed"},
	}))
	t:tdeq({soc:receive("*l")}, {"qwe"})
	t:tdeq({soc:receive("*l")}, {"rtyasd"})
	t:tdeq({soc:receive("*l")}, {nil, "closed", "fgh"})
	t:tdeq({soc:receive("*l")}, {nil, "closed", ""})
	t:tdeq({soc:receive("*l")}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_line_timeout(t)
	local soc = LineAllDecorator(FakeSocket({
		{"qw\re\r\nr\rty"},
		{"", "timeout"},
		{"asd\r\nfgh", "closed"},
	}))
	t:tdeq({soc:receive("*l")}, {"qwe"})
	t:tdeq({soc:receive("*l")}, {nil, "timeout", "rty"})
	t:tdeq({soc:receive("*l")}, {"asd"})
	t:tdeq({soc:receive("*l")}, {nil, "closed", "fgh"})
	t:tdeq({soc:receive("*l")}, {nil, "closed", ""})
	t:tdeq({soc:receive("*l")}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_all(t)
	local soc = LineAllDecorator(FakeSocket({
		{"qwerty", "closed"},
	}))
	t:tdeq({soc:receive("*a")}, {"qwerty"})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_all_timeout(t)
	local soc = LineAllDecorator(FakeSocket({
		{"qwe", "timeout"},
		{"rty", "closed"},
	}))
	t:tdeq({soc:receive("*a")}, {nil, "timeout", "qwe"})
	t:tdeq({soc:receive("*a")}, {"rty"})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})
end

---@param t testing.T
function test.remainder_all(t)
	local soc = LineAllDecorator(FakeSocket({
		{"qw\re\r\nr\rty"},
		{"asd\r\nfgh", "closed"},
	}))
	t:tdeq({soc:receive("*l")}, {"qwe"})
	t:tdeq({soc:receive("*a")}, {"r\rtyasd\r\nfgh"})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})
end

---@param t testing.T
function test.remainder_size(t)
	local soc = LineAllDecorator(FakeSocket({
		{"qw\re\r\nr\rty"},
		{"asd\r\nfgh", "closed"},
	}))
	t:tdeq({soc:receive("*l")}, {"qwe"})
	t:tdeq({soc:receive(1)}, {"r"})
	t:tdeq({soc:receive(1)}, {"\r"})
	t:tdeq({soc:receive(3)}, {"tya"})
	t:tdeq({soc:receive(100)}, {nil, "closed", "sd\13\nfgh"})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})
end

return test
