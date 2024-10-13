local HttpChunked = require("web.socket.HttpChunked")
local StringSocket = require("web.socket.StringSocket")
local LineAllDecorator = require("web.socket.LineAllDecorator")
local Headers = require("web.socket.Headers")

local test = {}

---@param t testing.T
function test.basic_no_trailing(t)
	local str_soc = StringSocket()
	local soc = LineAllDecorator(str_soc)

	local hc = HttpChunked(soc)
	hc:send("qwe")
	hc:send("rty")
	hc:close()

	t:eq(str_soc.remainder, "3\r\nqwe\r\n3\r\nrty\r\n0\r\n\r\n")

	local headers = Headers()
	t:tdeq({hc:receive(headers)}, {"qwe"})
	t:tdeq({hc:receive(headers)}, {"rty"})
	t:tdeq({hc:receive(headers)}, {})
	t:tdeq({hc:receive(headers)}, {nil, "timeout", ""})
end

---@param t testing.T
function test.basic_trailing(t)
	local str_soc = StringSocket()
	local soc = LineAllDecorator(str_soc)

	local headers = Headers()
	headers:add("Name", "value")

	local hc = HttpChunked(soc)
	hc:send("qwe")
	hc:close(headers)

	t:eq(str_soc.remainder, "3\r\nqwe\r\n0\r\nName: value\r\n\r\n")

	headers = Headers()
	t:tdeq({hc:receive(headers)}, {"qwe"})
	t:tdeq({hc:receive(headers)}, {})
	t:tdeq({hc:receive(headers)}, {nil, "timeout", ""})

	t:tdeq({headers:get("Name")}, {"value"})
end

return test
