local ExtendedSocket = require("web.socket.ExtendedSocket")
local StringSocket = require("web.socket.StringSocket")
local PrefixSocket = require("web.socket.PrefixSocket")
local SocketFilter = require("web.filter.SocketFilter")

local test = {}

---@param t testing.T
function test.socket_all(t)
	---@type {[string]: function}
	local tpl = require("web.socket.socket_tests")

	for k, f in pairs(tpl) do
		t.name = k
		local ext_soc = ExtendedSocket(SocketFilter(StringSocket()))
		local soc = PrefixSocket(ext_soc)
		f(t, soc, soc)
	end
end

---@param t testing.T
function test.socket_small_buffer_size(t)
	---@type {[string]: function}
	local tpl = require("web.socket.socket_tests")

	for buffer_size = 1, 16 do
		for k, f in pairs(tpl) do
			t.name = k
			local ext_soc = ExtendedSocket(SocketFilter(StringSocket()))
			local soc = PrefixSocket(ext_soc)
			ext_soc.upstream.buffer_size = buffer_size
			f(t, soc, soc)
		end
	end
end

---@param t testing.T
function test.receiveuntil_all(t)
	---@type {[string]: function}
	local tpl = require("web.socket.receiveuntil_tests")

	for k, f in pairs(tpl) do
		t.name = k
		local soc = ExtendedSocket(SocketFilter(StringSocket()))
		f(t, soc, soc)
	end
end

---@param t testing.T
function test.receiveuntil_small_buffer_size(t)
	---@type {[string]: function}
	local tpl = require("web.socket.receiveuntil_tests")

	for buffer_size = 1, 16 do
		for k, f in pairs(tpl) do
			t.name = k
			local soc = ExtendedSocket(SocketFilter(StringSocket()))
			soc.upstream.buffer_size = buffer_size
			f(t, soc, soc)
		end
	end
end

---@param t testing.T
function test.cosocket(t)
	---@type {[string]: function}
	local tpl = require("web.socket.cosocket_tests")

	for k, f in pairs(tpl) do
		t.name = k
		local soc = ExtendedSocket(SocketFilter(StringSocket()))
		soc.cosocket = true
		f(t, soc, soc)
	end
end

-- receiveany will return smaller strings on smaller buffers

---@param t testing.T
function test.receiveany_timeout(t)
	local soc = ExtendedSocket(SocketFilter(StringSocket()))

	soc:send("qwerty")

	t:tdeq({soc:receiveany(3)}, {"qwe"})
	t:tdeq({soc:receiveany(1)}, {"r"})
	t:tdeq({soc:receiveany(3)}, {"ty"})
	t:tdeq({soc:receiveany(3)}, {nil, "timeout", ""})
	t:tdeq({soc:receiveany(3)}, {nil, "timeout", ""})
end

---@param t testing.T
function test.receiveany_more_timeout(t)
	local soc = ExtendedSocket(SocketFilter(StringSocket()))

	soc:send("qwerty")

	t:tdeq({soc:receiveany(10)}, {"qwerty"})
	t:tdeq({soc:receiveany(10)}, {nil, "timeout", ""})
	t:tdeq({soc:receiveany(10)}, {nil, "timeout", ""})
end

---@param t testing.T
function test.receiveany_closed(t)
	local soc = ExtendedSocket(SocketFilter(StringSocket()))

	soc:send("qwerty")
	soc:close()

	t:tdeq({soc:receiveany(3)}, {"qwe"})
	t:tdeq({soc:receiveany(1)}, {"r"})
	t:tdeq({soc:receiveany(3)}, {"ty"})
	t:tdeq({soc:receiveany(3)}, {nil, "closed", ""})
	t:tdeq({soc:receiveany(3)}, {nil, "closed", ""})
end

---@param t testing.T
function test.receiveany_more_closed(t)
	local soc = ExtendedSocket(SocketFilter(StringSocket()))

	soc:send("qwerty")
	soc:close()

	t:tdeq({soc:receiveany(10)}, {"qwerty"})
	t:tdeq({soc:receiveany(10)}, {nil, "closed", ""})
	t:tdeq({soc:receiveany(10)}, {nil, "closed", ""})
end

return test
