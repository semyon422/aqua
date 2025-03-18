local Request = require("web.http.Request")
local StringSocket = require("web.socket.StringSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")

local test = {}

---@param t testing.T
function test.empty_headers(t)
	do return end

	local str_soc = StringSocket()

	local req = Request(ExtendedSocket(str_soc))

	req.method = "POST"
	req.uri = "/"

	t:tdeq({req:send("helloworld")}, {nil, "closed", 0})

	t:eq(str_soc.remainder, "POST / HTTP/1.1\r\n\r\n")
	str_soc:send("qwerty")

	local soc = ExtendedSocket(str_soc)
	local req = Request(soc)

	t:tdeq({req:receive("*a")}, {nil, "closed", ""})
	t:tdeq({req:receive("*a")}, {nil, "closed", ""})

	t:eq(req.method, "POST")
	t:eq(req.uri, "/")

	t:tdeq({soc:receive(100)}, {nil, "timeout", "qwerty"})
end

---@param t testing.T
function test.content_length(t)
	local str_soc = StringSocket()

	local req = Request(ExtendedSocket(str_soc))

	req.method = "POST"
	req.uri = "/"
	req.headers:set("Content-Length", 10)

	t:tdeq({req:send("")}, {0})
	t:eq(str_soc.remainder, "POST / HTTP/1.1\r\nContent-Length: 10\r\n\r\n")

	t:tdeq({req:send("helloworldqwerty")}, {nil, "closed", 10})
	t:eq(str_soc.remainder, "POST / HTTP/1.1\r\nContent-Length: 10\r\n\r\nhelloworld")

	str_soc:send("qwerty")

	local soc = ExtendedSocket(str_soc)
	local req = Request(soc)

	t:tdeq({req:receive(0)}, {""})

	t:eq(req.method, "POST")
	t:eq(req.uri, "/")
	t:eq(req.headers:get("Content-Length"), "10")

	t:tdeq({req:receive("*a")}, {"helloworld"})
	t:tdeq({req:receive("*a")}, {nil, "closed", ""})
	t:tdeq({req:receive("*a")}, {nil, "closed", ""})

	t:tdeq({soc:receive(100)}, {nil, "timeout", "qwerty"})
end

---@param t testing.T
function test.chunked(t)
	local str_soc = StringSocket()

	local req = Request(ExtendedSocket(str_soc))

	req.method = "POST"
	req.uri = "/"
	req.headers:set("Transfer-Encoding", "chunked")

	t:tdeq({req:send("hello")}, {5})
	t:tdeq({req:send("world")}, {5})
	t:tdeq({req:send("")}, {0})
	t:tdeq({req:send("qwerty")}, {nil, "closed", 0})
	t:tdeq({req:send("qwerty")}, {nil, "closed", 0})

	t:eq(str_soc.remainder, "POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n5\r\nworld\r\n0\r\n\r\n")
	str_soc:send("qwerty")

	local soc = ExtendedSocket(str_soc)
	local req = Request(soc)

	t:tdeq({req:receive(0)}, {""})

	t:eq(req.method, "POST")
	t:eq(req.uri, "/")
	t:eq(req.headers:get("Transfer-Encoding"), "chunked")

	t:tdeq({req:receive("*a")}, {"helloworld"})
	t:tdeq({req:receive("*a")}, {nil, "closed", ""})
	t:tdeq({req:receive("*a")}, {nil, "closed", ""})

	t:tdeq({soc:receive(100)}, {nil, "timeout", "qwerty"})
end

return test
