-- same tests as for ExtendedSocket
-- disabled

do return end

---@class tcp_test.Socket
---@field setoption fun(self: tcp_test.Socket, option: string, value: any): integer?
---@field bind fun(self: tcp_test.Socket, host: string, port: integer): integer?
---@field listen fun(self: tcp_test.Socket, backlog: integer): integer?
---@field settimeout fun(self: tcp_test.Socket, timeout: number): integer?
---@field connect fun(self: tcp_test.Socket, host: string, port: integer): integer?
---@field accept fun(self: tcp_test.Socket): tcp_test.Socket?
---@field close fun(self: tcp_test.Socket): integer?

---@type {tcp4: fun(): tcp_test.Socket}
local socket = require("socket")

local test = {}

---@return tcp_test.Socket
---@return tcp_test.Socket
---@return tcp_test.Socket
local function new_server_client()
	local server = assert(socket.tcp4())

	assert(server:setoption("reuseaddr", true))
	assert(server:bind("*", 8888))
	assert(server:listen(1024))
	assert(server:settimeout(0))

	local client = assert(socket.tcp4())
	assert(client:connect("127.0.0.1", 8888))
	assert(client:settimeout(0))

	local peer = assert(server:accept())
	peer:settimeout(0)

	return peer, client, server
end

---@param t testing.T
function test.all(t)
	---@type {[string]: function}
	local tpl = require("web.socket.socket_tests")

	for _, f in pairs(tpl) do
		local soc, client, server = new_server_client()
		f(t, soc, client)
		soc:close()
		client:close()
		server:close()
	end
end

return test
