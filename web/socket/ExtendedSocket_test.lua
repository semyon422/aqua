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

-- https://github.com/openresty/lua-nginx-module/blob/master/t/066-socket-receiveuntil.t

---@param t testing.T
function test.receiveuntil_timeout(t)
	local soc = ExtendedSocket(StringSocket())
	soc.chunk_size = 1

	soc:send("qwe||rty||asd")

	local read = soc:receiveuntil("||")

	t:tdeq({read()}, {"qwe"})
	t:tdeq({read()}, {"rty"})
	t:tdeq({read()}, {nil, "timeout", "asd"})
	t:tdeq({read()}, {nil, "timeout", ""})
	t:tdeq({read()}, {nil, "timeout", ""})
end

---@param t testing.T
function test.receiveuntil_closed(t)
	local soc = ExtendedSocket(StringSocket())
	soc.chunk_size = 1

	soc:send("qwe||rty||asd")
	soc:close()

	local read = soc:receiveuntil("||")

	t:tdeq({read()}, {"qwe"})
	t:tdeq({read()}, {"rty"})
	t:tdeq({read()}, {nil, "closed", "asd"})
	t:tdeq({read()}, {nil, "closed", ""})
	t:tdeq({read()}, {nil, "closed", ""})
end

---@param t testing.T
function test.receiveuntil_ambiguous_closed(t)
	local soc = ExtendedSocket(StringSocket())
	soc.chunk_size = 1

	soc:send("qweqwerty")
	soc:close()

	local read = soc:receiveuntil("qwerty")

	t:tdeq({read()}, {"qwe"})
	t:tdeq({read()}, {nil, "closed", ""})
	t:tdeq({read()}, {nil, "closed", ""})
end

---@param t testing.T
function test.receiveuntil_size_timeout(t)
	local soc = ExtendedSocket(StringSocket())

	soc:send("qwertyasdfgh")

	local read = soc:receiveuntil("asd")

	t:tdeq({read(4)}, {"qwer"})
	t:tdeq({read(4)}, {"ty"})
	t:tdeq({read(4)}, {})
	t:tdeq({read(4)}, {nil, "timeout", "fgh"})
	t:tdeq({read(4)}, {nil, "timeout", ""})
	t:tdeq({read(4)}, {nil, "timeout", ""})
end

-- ---@param t testing.T
-- function test.receiveuntil_size_mixed_timeout(t)
-- 	local soc = ExtendedSocket(StringSocket())

-- 	soc:send("qwertyasdfgh")

-- 	local read = soc:receiveuntil("asd")

-- 	t:tdeq({read(3)}, {"qwe"})
-- 	t:tdeq({soc:receive(1)}, {"r"})
-- 	t:tdeq({read(1)}, {"t"})
-- 	t:tdeq({soc:receive(1)}, {"y"})
-- 	t:tdeq({read(1)}, {""})
-- 	t:tdeq({soc:receive(1)}, {"f"})
-- 	t:tdeq({read(1)}, {})
-- 	t:tdeq({soc:receive(1)}, {"g"})
-- 	t:tdeq({read(1)}, {nil, "timeout", "h"})
-- 	t:tdeq({read(1)}, {nil, "timeout", ""})
-- 	t:tdeq({read(1)}, {nil, "timeout", ""})
-- end

-- ---@param t testing.T
-- function test.receiveuntil_size_mixed_consume_boundary_timeout(t)
-- 	local soc = ExtendedSocket(StringSocket())

-- 	soc:send("----abc----abc-")

-- 	local read = soc:receiveuntil("--abc")

-- 	t:tdeq({read(2)}, {"--"})
-- 	t:tdeq({soc:receive(1)}, {"-"})
-- 	t:tdeq({read(2)}, {"-a"})
-- 	t:tdeq({soc:receive(1)}, {"b"})
-- 	t:tdeq({read(2)}, {"c-"})
-- 	t:tdeq({soc:receive(1)}, {"-"})
-- 	t:tdeq({read(2)}, {""})
-- 	t:tdeq({soc:receive(1)}, {"-"})
-- 	t:tdeq({read(2)}, {})
-- 	t:tdeq({read(2)}, {nil, "timeout", ""})
-- 	t:tdeq({read(2)}, {nil, "timeout", ""})
-- 	t:tdeq({read(2)}, {nil, "timeout", ""})
-- end

return test
