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

	soc:send("preamble")

	fd:next_part(Headers():add("Name", "value1"))
	soc:send("hello")

	fd:next_part(Headers():add("Name", "value2"))
	soc:send("world")

	fd:next_part()

	t:eq(str_soc.remainder, ([[
preamble
--abcdef
Name: value1

hello
--abcdef
Name: value2

world
--abcdef--
]]):gsub("\n", "\r\n"))

	t:tdeq({fd:receive_preamble()}, {"preamble"})

	local headers = assert(fd:receive())
	t:tdeq(headers.headers, {name = {"value1"}})
	t:tdeq({ExtendedSocket(fd.bsoc):receive("*a")}, {"hello"})

	local headers = assert(fd:receive())
	t:tdeq(headers.headers, {name = {"value2"}})
	t:tdeq({ExtendedSocket(fd.bsoc):receive("*a")}, {"world"})

	local headers, err = fd:receive()
	t:assert(not headers)
	t:eq(err, "closed")
end

return test
