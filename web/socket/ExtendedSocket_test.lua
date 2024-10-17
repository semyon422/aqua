local ExtendedSocket = require("web.socket.ExtendedSocket")
local StringSocket = require("web.socket.StringSocket")

local test = {}

---@param t testing.T
function test.all(t)
	---@type {[string]: function}
	local tpl = require("web.socket.socket_tests")

	for _, f in pairs(tpl) do
		local soc = ExtendedSocket(StringSocket())
		f(t, soc, soc)
	end
end

---@param t testing.T
function test.chunk_size_1(t)
	---@type {[string]: function}
	local tpl = require("web.socket.socket_tests")

	for _, f in pairs(tpl) do
		local soc = ExtendedSocket(StringSocket())
		soc.chunk_size = 1
		f(t, soc, soc)
	end
end

---@param t testing.T
function test.receiveany_timeout(t)
	local soc = ExtendedSocket(StringSocket())

	soc:send("qwerty")

	t:tdeq({soc:receiveany(3)}, {"qwe"})
	t:tdeq({soc:receiveany(1)}, {"r"})
	t:tdeq({soc:receiveany(3)}, {"ty"})
	t:tdeq({soc:receiveany(3)}, {nil, "timeout"})
	t:tdeq({soc:receiveany(3)}, {nil, "timeout"})
end

---@param t testing.T
function test.receiveany_closed(t)
	local soc = ExtendedSocket(StringSocket())

	soc:send("qwerty")
	soc:close()

	t:tdeq({soc:receiveany(3)}, {"qwe"})
	t:tdeq({soc:receiveany(1)}, {"r"})
	t:tdeq({soc:receiveany(3)}, {"ty"})
	t:tdeq({soc:receiveany(3)}, {nil, "closed"})
	t:tdeq({soc:receiveany(3)}, {nil, "closed"})
end

return test