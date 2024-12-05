local SocketResponse = require("web.luasocket.SocketResponse")
local StringSocket = require("web.socket.StringSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")

local test = {}

---@param t testing.T
function test.empty_headers(t)
	local str_soc = StringSocket()

	local res = SocketResponse(ExtendedSocket(str_soc))

	res.status = 200

	t:tdeq({res:send("helloworld")}, {nil, "closed", 0})

	t:eq(str_soc.remainder, "HTTP/1.1 200 OK\r\n\r\n")
	str_soc:send("qwerty")

	local soc = ExtendedSocket(str_soc)
	local res = SocketResponse(soc)

	t:tdeq({res:receive("*a")}, {nil, "closed", ""})
	t:tdeq({res:receive("*a")}, {nil, "closed", ""})

	t:eq(res.status, 200)

	t:tdeq({soc:receive(100)}, {nil, "timeout", "qwerty"})
end

---@param t testing.T
function test.content_length(t)
	local str_soc = StringSocket()

	local res = SocketResponse(ExtendedSocket(str_soc))

	res.status = 200
	res.headers:set("Content-Length", 10)

	t:tdeq({res:send("helloworldqwerty")}, {nil, "closed", 10})

	t:eq(str_soc.remainder, "HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nhelloworld")
	str_soc:send("qwerty")

	local soc = ExtendedSocket(str_soc)
	local res = SocketResponse(soc)

	t:tdeq({res:receive("*a")}, {"helloworld"})
	t:tdeq({res:receive("*a")}, {nil, "closed", ""})
	t:tdeq({res:receive("*a")}, {nil, "closed", ""})

	t:eq(res.status, 200)
	t:eq(res.headers:get("Content-Length"), "10")

	t:tdeq({soc:receive(100)}, {nil, "timeout", "qwerty"})
end

---@param t testing.T
function test.chunked(t)
	local str_soc = StringSocket()

	local res = SocketResponse(ExtendedSocket(str_soc))

	res.status = 200
	res.headers:set("Transfer-Encoding", "chunked")

	t:tdeq({res:send("hello")}, {5})
	t:tdeq({res:send("world")}, {5})
	t:tdeq({res:send("")}, {0})
	t:tdeq({res:send("qwerty")}, {nil, "closed", 0})
	t:tdeq({res:send("qwerty")}, {nil, "closed", 0})

	t:eq(str_soc.remainder, "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n5\r\nworld\r\n0\r\n\r\n")
	str_soc:send("qwerty")

	local soc = ExtendedSocket(str_soc)
	local res = SocketResponse(soc)

	t:tdeq({res:receive("*a")}, {"helloworld"})
	t:tdeq({res:receive("*a")}, {nil, "closed", ""})
	t:tdeq({res:receive("*a")}, {nil, "closed", ""})

	t:eq(res.status, 200)
	t:eq(res.headers:get("Transfer-Encoding"), "chunked")

	t:tdeq({soc:receive(100)}, {nil, "timeout", "qwerty"})
end

return test
