local ChunkedEncoding = require("web.http.ChunkedEncoding")
local StringSocket = require("web.socket.StringSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")
local PrefixSocket = require("web.socket.PrefixSocket")
local Headers = require("web.http.Headers")

local test = {}

---@param enc web.ChunkedEncoding
---@param chunked_content string
local function test_by_byte(enc, chunked_content)
	---@type string[]
	local out = {}

	local i = 1
	while true do
		local data, err = enc:receiveany(1)
		if not data then
			table.insert(out, data)
		else

		end

	end
end

---@param t testing.T
function test.basic_no_trailing(t)
	local str_soc = StringSocket()
	local soc = PrefixSocket(ExtendedSocket(str_soc))

	local enc = ChunkedEncoding(soc)
	enc:send("qwe")
	enc:send("rty")
	enc:send()

	t:eq(str_soc.remainder, "3\r\nqwe\r\n3\r\nrty\r\n0\r\n\r\n")

	t:tdeq({enc:receive(3)}, {"qwe"})
	t:tdeq({enc:receive(3)}, {"rty"})
	t:tdeq({enc:receive(3)}, {})
	t:tdeq({enc:receive(3)}, {nil, "timeout", ""})
end

---@param t testing.T
function test.basic_trailing(t)
	local str_soc = StringSocket()
	local soc = PrefixSocket(ExtendedSocket(str_soc))

	local enc = ChunkedEncoding(soc)
	enc.headers:add("Name", "value")
	enc:send("qwe")
	enc:send()

	t:eq(str_soc.remainder, "3\r\nqwe\r\n0\r\nName: value\r\n\r\n")

	enc.headers = Headers()
	t:tdeq({enc:receive(3)}, {"qwe"})
	t:tdeq({enc:receive(3)}, {})
	t:tdeq({enc:receive(3)}, {nil, "timeout", ""})

	t:tdeq({enc.headers:get("Name")}, {"value"})
end

---@param t testing.T
function test.multiple_incomplete_timeout(t)
	local str_soc = StringSocket()
	local soc = PrefixSocket(ExtendedSocket(str_soc))

	local enc = ChunkedEncoding(soc)
	enc:send("qwert")
	enc:send("yuiop")
	-- enc:send()

	t:eq(str_soc.remainder, "5\r\nqwert\r\n5\r\nyuiop\r\n")

	t:tdeq({enc:receive(3)}, {"qwe"})
	t:tdeq({enc:receive(3)}, {"rt"})
	t:tdeq({enc:receive(3)}, {"yui"})
	t:tdeq({enc:receive(3)}, {"op"})
	t:tdeq({enc:receive(3)}, {nil, "timeout", ""})
	t:tdeq({enc:receive(3)}, {nil, "timeout", ""})
end

---@param t testing.T
function test.size_line_incomplete_timeout(t)
	local str_soc = StringSocket()
	local soc = PrefixSocket(ExtendedSocket(str_soc))

	local enc = ChunkedEncoding(soc)

	str_soc:send("5;helloworld")

	t:tdeq({enc:receive(3)}, {nil, "timeout", ""})
	t:tdeq({enc:receive(3)}, {nil, "timeout", ""})

	str_soc:send("\r\n")

	t:tdeq({enc:receive(3)}, {nil, "timeout", ""})
	t:tdeq({enc:receive(3)}, {nil, "timeout", ""})

	str_soc:send("hello")

	t:tdeq({enc:receive(10)}, {"hello"})
	t:tdeq({enc:receive(10)}, {nil, "timeout", ""})
end

return test
