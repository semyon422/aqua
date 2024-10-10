local FakeStringSocket = require("web.socket.FakeStringSocket")

local test = {}

---@param t testing.T
function test.receive_exact(t)
	local soc = FakeStringSocket("qwerty")

	t:tdeq({soc:receive(3)}, {"qwe"})
	t:tdeq({soc:receive(3)}, {"rty"})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_size_more(t)
	local soc = FakeStringSocket("qwerty")

	t:tdeq({soc:receive(3)}, {"qwe"})
	t:tdeq({soc:receive(4)}, {nil, "closed", "rty"})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
end

return test
