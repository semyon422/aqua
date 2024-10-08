local LineAllDecorator = require("web.socket.LineAllDecorator")
local FakeSocket = require("web.socket.FakeSocket")

local test = {}

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
function test.receive_all(t)
	local soc = LineAllDecorator(FakeSocket({
		{"qwe"},
		{"rty", "closed"},
	}))
	t:tdeq({soc:receive("*a")}, {"qwerty"})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})
end

return test
