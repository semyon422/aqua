local SocketFilter = require("web.filter.SocketFilter")
local StringSocket = require("web.socket.StringSocket")

local test = {}

---@param t testing.T
function test.send(t)
	local soc = StringSocket("", 7)
	local fil = SocketFilter(soc)

	t:eq(fil:send("hello"), 5)
	t:eq(fil:send("world"), 2)
	t:eq(fil:send("rld"), 0)
	t:eq(fil:send("rld"), 0)

	soc:close()
	t:eq(fil:send("rld"), nil)
	t:eq(fil:send("rld"), nil)
end

---@param t testing.T
function test.receive(t)
	local soc = StringSocket("hellowo")
	local fil = SocketFilter(soc)

	t:eq(fil:receive(5), "hello")
	t:eq(fil:receive(5), "wo")
	t:eq(fil:receive(3), "")
	t:eq(fil:receive(3), "")

	soc:close()
	t:eq(fil:receive(3), nil)
	t:eq(fil:receive(3), nil)
end

return test
