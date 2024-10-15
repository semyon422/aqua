local SocketRequest = require("web.socket.SocketRequest")
local StringSocket = require("web.socket.StringSocket")
local LineAllDecorator = require("web.socket.LineAllDecorator")

local test = {}

local request = "POST /users HTTP/1.1\r\nContent-Length: 4\r\n\r\nuser"

---@param t testing.T
function test.receive(t)
	local str_soc = StringSocket(request)
	local soc = LineAllDecorator(str_soc)
	soc:close()
	local req = SocketRequest(soc)

	t:tdeq({req:receive("*a")}, {"user"})
	t:eq(req.method, "POST")
	t:eq(req.uri, "/users")
	t:eq(req.headers:get("Content-Length"), "4")
end

---@param t testing.T
function test.send(t)
	local str_soc = StringSocket()
	local soc = LineAllDecorator(str_soc)
	local req = SocketRequest(soc)

	req.method = "POST"
	req.uri = "/users"
	req.headers:add("Content-Length", 4)
	req:send("user")

	t:eq(str_soc.remainder, request)
end

return test
