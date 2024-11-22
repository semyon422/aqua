local ChunkedEncoding = require("web.http.ChunkedEncoding")
local StringSocket = require("web.socket.StringSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")
local Headers = require("web.http.Headers")

local test = {}

---@param t testing.T
function test.basic_no_trailing(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local enc = ChunkedEncoding(soc)
	enc:send("qwe")
	enc:send("rty")
	enc:close()

	t:eq(str_soc.remainder, "3\r\nqwe\r\n3\r\nrty\r\n0\r\n\r\n")

	t:tdeq({enc:receive()}, {"qwe"})
	t:tdeq({enc:receive()}, {"rty"})
	t:tdeq({enc:receive()}, {})
	t:tdeq({enc:receive()}, {nil, "timeout", ""})
end

---@param t testing.T
function test.basic_trailing(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local enc = ChunkedEncoding(soc)
	enc.headers:add("Name", "value")
	enc:send("qwe")
	enc:close()

	t:eq(str_soc.remainder, "3\r\nqwe\r\n0\r\nName: value\r\n\r\n")

	enc.headers = Headers()
	t:tdeq({enc:receive()}, {"qwe"})
	t:tdeq({enc:receive()}, {})
	t:tdeq({enc:receive()}, {nil, "timeout", ""})

	t:tdeq({enc.headers:get("Name")}, {"value"})
end

return test
