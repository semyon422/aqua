local Multipart = require("web.content.Multipart")
local StringSocket = require("web.socket.StringSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")
local Headers = require("web.http.Headers")

local test = {}

---@param t testing.T
function test.basic(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local mp = Multipart(soc, "abcdef")

	soc:send("preamble")

	mp:next_part(Headers():add("Name", "value1"))
	soc:send("hello")

	mp:next_part(Headers():add("Name", "value2"))
	soc:send("world")

	mp:next_part()
	soc:send("epilogue")

	soc:close()

	t:eq(str_soc.remainder, ([[
preamble
--abcdef
Name: value1

hello
--abcdef
Name: value2

world
--abcdef--
epilogue]]):gsub("\n", "\r\n"))

	t:tdeq({mp:receive_preamble()}, {"preamble"})

	local headers = assert(mp:receive())
	t:tdeq(headers.headers, {name = {"value1"}})
	t:tdeq({ExtendedSocket(mp.bsoc):receive("*a")}, {"hello"})

	local headers = assert(mp:receive())
	t:tdeq(headers.headers, {name = {"value2"}})
	t:tdeq({ExtendedSocket(mp.bsoc):receive("*a")}, {"world"})

	local headers, err = mp:receive()
	t:assert(not headers)
	t:eq(err, "no parts")

	t:tdeq({mp:receive_epilogue()}, {"epilogue"})
end

---@param t testing.T
function test.basic_no_preamble_no_epilogue(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local mp = Multipart(soc, "abcdef")

	soc:send("")

	mp:next_part(Headers():add("Name", "value1"))
	soc:send("hello")

	mp:next_part(Headers():add("Name", "value2"))
	soc:send("world")

	mp:next_part()
	soc:send("")

	soc:close()

	t:eq(str_soc.remainder, ([[

--abcdef
Name: value1

hello
--abcdef
Name: value2

world
--abcdef--
]]):gsub("\n", "\r\n"))

	t:tdeq({mp:receive_preamble()}, {""})

	local headers = assert(mp:receive())
	t:tdeq(headers.headers, {name = {"value1"}})
	t:tdeq({ExtendedSocket(mp.bsoc):receive("*a")}, {"hello"})

	local headers = assert(mp:receive())
	t:tdeq(headers.headers, {name = {"value2"}})
	t:tdeq({ExtendedSocket(mp.bsoc):receive("*a")}, {"world"})

	local headers, err = mp:receive()
	t:assert(not headers)
	t:eq(err, "no parts")

	t:tdeq({mp:receive_epilogue()}, {nil, "closed", ""})
end

return test
