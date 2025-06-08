local Headers = require("web.http.Headers")
local StringSocket = require("web.socket.StringSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")

local test = {}

---@param t testing.T
function test.add_set_get(t)
	local headers = Headers()
	headers:add("Name1", "value1")
	headers:add("Name1", "value2")
	headers:add("Name2", "value2")

	t:tdeq({headers:get("Name1")}, {"value1", "value2"})
	t:tdeq({headers:get("name1")}, {"value1", "value2"}) -- lowercase
	t:tdeq({headers:get("Name2")}, {"value2"})

	headers:set("Name1", "value3")
	headers:set("Name2", {"value3"})

	t:tdeq({headers:get("Name1")}, {"value3"})
	t:tdeq({headers:get("Name2")}, {"value3"})
end

---@param t testing.T
function test.multiple(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local headers = Headers()
	headers:add("Name1", "value1")
	headers:add("Name1", "value2")
	headers:add("Name2", "value2")
	headers:send(soc)

	t:eq(str_soc.remainder, "Name1: value1\r\nName1: value2\r\nName2: value2\r\n\r\n")

	headers = Headers()
	t:eq(headers:receive(soc), headers)
	t:tdeq({headers:get("Name1")}, {"value1", "value2"})
	t:tdeq({headers:get("Name2")}, {"value2"})
end

---@param t testing.T
function test.empty(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local headers = Headers()
	headers:send(soc)

	t:eq(str_soc.remainder, "\r\n")

	headers = Headers()
	t:eq(headers:receive(soc), headers)
	t:tdeq(headers.headers, {})
end

---@param t testing.T
function test.folded_space(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	str_soc:send("Name: value1\r\n value2\r\n\r\n")

	local headers = Headers()
	t:eq(headers:receive(soc), headers)
	t:tdeq(headers.headers, {name = {"value1 value2"}})
end

---@param t testing.T
function test.folded_tab(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	str_soc:send("Name: value1\r\n\tvalue2\r\n\r\n")

	local headers = Headers()
	t:eq(headers:receive(soc), headers)
	t:tdeq(headers.headers, {name = {"value1\tvalue2"}})
end

---@param t testing.T
function test.timeout(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	str_soc:send("Name: value")

	local headers = Headers()
	t:tdeq({headers:receive(soc)}, {nil, "timeout"})
	t:tdeq(headers.headers, {})
end

---@param t testing.T
function test.malformed(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	str_soc:send("Name value\r\n\r\n")

	local headers = Headers()
	t:tdeq({headers:receive(soc)}, {nil, "malformed headers"})
	t:tdeq(headers.headers, {})
end

---@param t testing.T
function test.no_end_line_timeout(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	str_soc:send("Name: value\r\n")

	local headers = Headers()
	t:tdeq({headers:receive(soc)}, {nil, "timeout"})
	t:tdeq(headers.headers, {})
end

---@param t testing.T
function test.no_end_line_folded_timeout(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	str_soc:send("Name: value1\r\n value2\r\n")

	local headers = Headers()
	t:tdeq({headers:receive(soc)}, {nil, "timeout"})
	t:tdeq(headers.headers, {})
end

return test
