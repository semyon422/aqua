local SocketResponse = require("web.luasocket.SocketResponse")
local StringSocket = require("web.socket.StringSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")
local SocketFilter = require("web.filter.SocketFilter")

local test = {}

local response_full = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello"

---@param t testing.T
function test.receive_length(t)
	local str_soc = StringSocket(response_full)
	local soc = ExtendedSocket(SocketFilter(str_soc))
	soc:close()
	local res = SocketResponse(soc)

	t:tdeq({res:receive("*a")}, {"hello"})
	t:eq(res.status, 200)
	t:eq(res.headers:get("Content-Length"), "5")
end

---@param t testing.T
function test.send_length(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(SocketFilter(str_soc))
	local res = SocketResponse(soc)

	res.status = 200
	res.headers:add("Content-Length", 5)
	res:send("hello")

	t:eq(str_soc.remainder, response_full)
end

return test
