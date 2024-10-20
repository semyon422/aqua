local BufferSocket = require("web.socket.BufferSocket")
local StringSocket = require("web.socket.StringSocket")

local test = {}

---@param t testing.T
function test.basic(t)
	local str_soc = StringSocket()
	local soc = BufferSocket(str_soc, 4)

	soc:send("qwertyuiopasdf")

	t:tdeq({soc:receive(1)}, {"q"})

	t:eq(soc.remainder, "wert")
	t:eq(str_soc.remainder, "yuiopasdf")

	t:tdeq({soc:receive(1)}, {"w"})

	t:eq(soc.remainder, "ert")
	t:eq(str_soc.remainder, "yuiopasdf")

	t:tdeq({soc:receive(5)}, {"ertyu"})

	t:eq(soc.remainder, "iopa")
	t:eq(str_soc.remainder, "sdf")

	t:tdeq({soc:receive(6)}, {"iopasd"})

	t:eq(soc.remainder, "f")
	t:eq(str_soc.remainder, "")

	t:tdeq({soc:receive(6)}, {nil, "timeout", "f"})
end

return test
