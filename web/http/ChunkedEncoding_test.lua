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

	local headers = Headers()
	t:tdeq({enc:receive(headers)}, {"qwe"})
	t:tdeq({enc:receive(headers)}, {"rty"})
	t:tdeq({enc:receive(headers)}, {})
	t:tdeq({enc:receive(headers)}, {nil, "timeout", ""})
end

---@param t testing.T
function test.basic_trailing(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local headers = Headers()
	headers:add("Name", "value")

	local enc = ChunkedEncoding(soc)
	enc:send("qwe")
	enc:close(headers)

	t:eq(str_soc.remainder, "3\r\nqwe\r\n0\r\nName: value\r\n\r\n")

	headers = Headers()
	t:tdeq({enc:receive(headers)}, {"qwe"})
	t:tdeq({enc:receive(headers)}, {})
	t:tdeq({enc:receive(headers)}, {nil, "timeout", ""})

	t:tdeq({headers:get("Name")}, {"value"})
end

return test
