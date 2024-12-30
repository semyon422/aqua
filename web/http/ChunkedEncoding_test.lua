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
	t:tdeq({enc:send("qwe")}, {3})
	t:tdeq({enc:send("rty")}, {3})
	t:tdeq({enc:send("")}, {0})
	t:tdeq({enc:send("")}, {nil, "closed", 0})
	t:tdeq({enc:send("zxc")}, {nil, "closed", 0})

	t:eq(str_soc.remainder, "3\r\nqwe\r\n3\r\nrty\r\n0\r\n\r\n")

	t:tdeq({enc:receiveany(100)}, {"qwe"})
	t:tdeq({enc:receiveany(100)}, {"rty"})
	t:tdeq({enc:receiveany(100)}, {nil, "closed"})
	t:tdeq({enc:receiveany(100)}, {nil, "closed"})
end

---@param t testing.T
function test.basic_trailing(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local enc = ChunkedEncoding(soc)
	enc.headers:add("Name", "value")
	enc:send("qwe")
	enc:send("")

	t:eq(str_soc.remainder, "3\r\nqwe\r\n0\r\nName: value\r\n\r\n")

	enc.headers = Headers()
	t:tdeq({enc:receiveany(100)}, {"qwe"})
	t:tdeq({enc:receiveany(100)}, {nil, "closed"})
	t:tdeq({enc:receiveany(100)}, {nil, "closed"})

	t:tdeq({enc.headers:get("Name")}, {"value"})
end

---@param t testing.T
function test.multiple_incomplete_timeout(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local enc = ChunkedEncoding(soc)
	enc:send("qwert")
	enc:send("yuiop")
	-- enc:send("")

	t:eq(str_soc.remainder, "5\r\nqwert\r\n5\r\nyuiop\r\n")

	t:tdeq({enc:receiveany(3)}, {"qwe"})
	t:tdeq({enc:receiveany(3)}, {"rt"})
	t:tdeq({enc:receiveany(3)}, {"yui"})
	t:tdeq({enc:receiveany(3)}, {"op"})
	t:tdeq({enc:receiveany(3)}, {nil, "timeout"})
	t:tdeq({enc:receiveany(3)}, {nil, "timeout"})
end

---@param t testing.T
function test.basic_no_trailing_extended_size(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local enc = ExtendedSocket(ChunkedEncoding(soc))
	enc:send("qwe")
	enc:send("rty")
	enc:send("")

	t:eq(str_soc.remainder, "3\r\nqwe\r\n3\r\nrty\r\n0\r\n\r\n")

	t:tdeq({enc:receive(4)}, {"qwer"})
	t:tdeq({enc:receive(4)}, {nil, "closed", "ty"})
	t:tdeq({enc:receive(4)}, {nil, "closed", ""})
	t:tdeq({enc:receive(4)}, {nil, "closed", ""})
end

---@param t testing.T
function test.basic_no_trailing_extended_all(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local enc = ExtendedSocket(ChunkedEncoding(soc))
	enc:send("qwe")
	enc:send("rty")
	enc:send("")

	t:eq(str_soc.remainder, "3\r\nqwe\r\n3\r\nrty\r\n0\r\n\r\n")

	t:tdeq({enc:receive("*a")}, {"qwerty"})
	t:tdeq({enc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({enc:receive("*a")}, {nil, "closed", ""})
end

---@param t testing.T
function test.basic_no_trailing_extended_all_timeout(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local enc = ExtendedSocket(ChunkedEncoding(soc))
	enc:send("qwe")
	enc:send("rty")
	-- enc:send("")

	t:eq(str_soc.remainder, "3\r\nqwe\r\n3\r\nrty\r\n")

	t:tdeq({enc:receive("*a")}, {nil, "timeout", "qwerty"})
	t:tdeq({enc:receive("*a")}, {nil, "timeout", ""})
	t:tdeq({enc:receive("*a")}, {nil, "timeout", ""})
end

---@param t testing.T
function test.receive_early_close(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local enc = ExtendedSocket(ChunkedEncoding(soc))
	enc:send("qwe")
	enc:send("rty")
	-- enc:send("")

	str_soc:close()

	t:eq(str_soc.remainder, "3\r\nqwe\r\n3\r\nrty\r\n")

	t:tdeq({enc:receive("*a")}, {nil, "closed early", "qwerty"})
	t:tdeq({enc:receive("*a")}, {nil, "closed early", ""})
	t:tdeq({enc:receive("*a")}, {nil, "closed early", ""})
end

return test
