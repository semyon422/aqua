local SocketRequest = require("web.luasocket.SocketRequest")
local StringSocket = require("web.socket.StringSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")

local test = {}

---@param t testing.T
function test.content_length(t)
	local str_soc = StringSocket()

	local req = SocketRequest(ExtendedSocket(str_soc))

	req.method = "POST"
	req.uri = "/"
	req.headers:set("Content-Length", 10)

	t:tdeq({req:send("helloworldqwerty")}, {nil, "closed", 10})

	t:eq(str_soc.remainder, "POST / HTTP/1.1\r\nContent-Length: 10\r\n\r\nhelloworld")
	str_soc:send("qwerty")

	local soc = ExtendedSocket(str_soc)
	local req = SocketRequest(soc)

	t:tdeq({req:receive("*a")}, {"helloworld"})
	t:tdeq({req:receive("*a")}, {nil, "closed", ""})
	t:tdeq({req:receive("*a")}, {nil, "closed", ""})

	t:eq(req.method, "POST")
	t:eq(req.uri, "/")
	t:eq(req.headers:get("Content-Length"), "10")

	t:tdeq({soc:receive(100)}, {nil, "timeout", "qwerty"})
end

return test
