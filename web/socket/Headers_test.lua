local Headers = require("web.socket.Headers")
local StringSocket = require("web.socket.StringSocket")
local LineAllDecorator = require("web.socket.LineAllDecorator")
local AsyncSocket = require("web.socket.AsyncSocket")

local test = {}

---@param t testing.T
function test.basic(t)
	local headers = Headers()
	headers:add("Name1", "value1")
	headers:add("Name1", "value2")
	headers:add("Name2", "value2")

	local str_soc = StringSocket()
	local soc = AsyncSocket(LineAllDecorator(str_soc))
	headers:send(soc)

	t:eq(str_soc.remainder, "Name1: value1\r\nName1: value2\r\nName2: value2\r\n\r\n")

	headers = Headers()
	t:tdeq({headers:receive(soc)}, {true})
	t:tdeq({headers:get("Name1")}, {"value1", "value2"})
	t:tdeq({headers:get("name1")}, {"value1", "value2"})
	t:tdeq({headers:get("Name2")}, {"value2"})
end

---@param t testing.T
function test.empty(t)
	local headers = Headers()

	local str_soc = StringSocket()
	local soc = AsyncSocket(LineAllDecorator(str_soc))
	headers:send(soc)

	t:eq(str_soc.remainder, "\r\n")

	headers = Headers()
	t:tdeq({headers:receive(soc)}, {true})
	t:tdeq(headers.headers, {})
end

return test
