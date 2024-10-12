local HttpChunked = require("web.socket.HttpChunked")
local FakeStringSocket = require("web.socket.FakeStringSocket")
local LineAllDecorator = require("web.socket.LineAllDecorator")
local Headers = require("web.socket.Headers")

local test = {}

---@param t testing.T
function test.basic_no_trailing(t)
	local str_soc = FakeStringSocket()
	local soc = LineAllDecorator(str_soc)

	local headers = Headers()

	local hc = HttpChunked(soc)
	hc:encode("qwe")
	hc:encode("rty")
	hc:encode()

	t:eq(str_soc.remainder, "3\r\nqwe\r\n3\r\nrty\r\n0\r\n\r\n")

	t:tdeq({hc:decode(headers)}, {"qwe"})
	t:tdeq({hc:decode(headers)}, {"rty"})
	t:tdeq({hc:decode(headers)}, {})
	t:tdeq({hc:decode(headers)}, {nil, "timeout"})
end

---@param t testing.T
function test.basic_trailing(t)
	local str_soc = FakeStringSocket()
	local soc = LineAllDecorator(str_soc)

	local headers = Headers()
	headers:add("Name", "value")

	local hc = HttpChunked(soc)
	hc:encode("qwe")
	hc:encode(nil, headers)

	t:eq(str_soc.remainder, "3\r\nqwe\r\n0\r\nName: value\r\n\r\n")

	headers = Headers()
	t:tdeq({hc:decode(headers)}, {"qwe"})
	t:tdeq({hc:decode(headers)}, {})
	t:tdeq({hc:decode(headers)}, {nil, "timeout"})

	t:tdeq(headers.headers, {Name = "value"})
end

return test
