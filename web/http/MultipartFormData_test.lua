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

	t:tdeq({fd:receive_preamble()}, {"preamble"})

	local headers, bsoc = fd:receive()
	---@cast headers web.Headers
	t:assert(headers)
	t:tdeq(headers.headers, {name = {"value"}})
	bsoc = ExtendedSocket(bsoc)
	t:tdeq({bsoc:receive("*a")}, {"hello"})

	local headers, bsoc = fd:receive()
	---@cast headers web.Headers
	t:assert(headers)
	t:tdeq(headers.headers, {name = {"value"}})
	bsoc = ExtendedSocket(bsoc)
	t:tdeq({bsoc:receive("*a")}, {"world"})

	local headers, bsoc = fd:receive()
	t:assert(not headers)
	t:eq(bsoc, "closed")
end

return test
