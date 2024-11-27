local Headers = require("web.http.Headers")
local StringSocket = require("web.socket.StringSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")

local test = {}

---@param t testing.T
function test.basic(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local headers = Headers(soc)
	headers:add("Name1", "value1")
	headers:add("Name1", "value2")
	headers:add("Name2", "value2")
	headers:send()

	t:eq(str_soc.remainder, "Name1: value1\r\nName1: value2\r\nName2: value2\r\n\r\n")

	headers = Headers(soc)
	t:tdeq({headers:receive()}, {true})
	t:tdeq({headers:get("Name1")}, {"value1", "value2"})
	t:tdeq({headers:get("name1")}, {"value1", "value2"})
	t:tdeq({headers:get("Name2")}, {"value2"})
end

---@param t testing.T
function test.empty(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local headers = Headers(soc)
	headers:send()

	t:eq(str_soc.remainder, "\r\n")

	headers = Headers(soc)
	t:tdeq({headers:receive()}, {true})
	t:tdeq(headers.headers, {})
end

return test
