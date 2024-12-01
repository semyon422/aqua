local MultipartFormData = require("web.http.MultipartFormData")
local StringSocket = require("web.socket.StringSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")
local Headers = require("web.http.Headers")

local test = {}

---@param t testing.T
function test.basic(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local fd = MultipartFormData(soc, "abcdef")

	soc:send("preamble\r\n")

	fd:send_boundary()

	local headers = Headers(soc)
	headers:add("Name", "value")
	headers:send()
	soc:send("hello")
	soc:send("\r\n")

	fd:send_boundary()

	local headers = Headers(soc)
	headers:add("Name", "value")
	headers:send()
	soc:send("world")
	soc:send("\r\n")

	fd:send_boundary(true)

	t:eq(str_soc.remainder, ([[
preamble
--abcdef
Name: value

hello
--abcdef
Name: value

world
--abcdef--
]]):gsub("\n", "\r\n"))

	t:tdeq({fd.receive_until_boundary()}, {"preamble"})
	t:eq(soc:receive("*l"), "")

	local headers = Headers(soc)
	headers:receive()
	t:tdeq(headers.headers, {name = {"value"}})

	t:eq(fd.receive_until_boundary(), "hello")
	t:eq(soc:receive("*l"), "")

	local headers = Headers(soc)
	headers:receive()
	t:tdeq(headers.headers, {name = {"value"}})

	t:eq(fd.receive_until_boundary(), "world")
	t:eq(soc:receive("*l"), "--")
end

return test
