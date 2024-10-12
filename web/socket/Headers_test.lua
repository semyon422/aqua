local Headers = require("web.socket.Headers")
local FakeStringSocket = require("web.socket.FakeStringSocket")
local LineAllDecorator = require("web.socket.LineAllDecorator")

local test = {}

---@param t testing.T
function test.basic(t)
	local headers = Headers()
	headers:add("Name1", "value1")
	headers:add("Name2", "value2")

	local data = headers:encode()

	t:eq(data, "Name1: value1\r\nName2: value2\r\n\r\n")

	headers = Headers()
	local soc = LineAllDecorator(FakeStringSocket(data))
	t:tdeq({headers:decode(function() return soc:receive("*l") end)}, {true})
	t:tdeq(headers.headers, {
		Name1 = "value1",
		Name2 = "value2",
	})
end

---@param t testing.T
function test.empty(t)
	local headers = Headers()

	local data = headers:encode()

	t:eq(data, "\r\n")

	headers = Headers()
	local soc = LineAllDecorator(FakeStringSocket(data))
	t:tdeq({headers:decode(function() return soc:receive("*l") end)}, {true})
	t:tdeq(headers.headers, {})
end

return test
