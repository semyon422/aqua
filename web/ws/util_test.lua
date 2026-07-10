local ws_util = require("web.ws.util")

local test = {}

---@class web.FakeTcpSocketForUtil
---@field timeout number?
local FakeTcpSocket = {}
FakeTcpSocket.__index = FakeTcpSocket

---@param timeout number
function FakeTcpSocket:settimeout(timeout)
	self.timeout = timeout
end

---@param t testing.T
function test.configure_tcp_socket(t)
	local tcp_socket = setmetatable({}, FakeTcpSocket)
	local ssl_params = {
		verify = "peer",
		nested = {"value"},
	}

	local configured = ws_util.tcp({
		tcp_socket = tcp_socket --[[@as any]],
		timeout = 7,
		ssl_params = ssl_params,
	})

	t:eq(configured, tcp_socket)
	t:eq(tcp_socket.timeout, 7)
	t:tdeq(tcp_socket.ssl_params, ssl_params)
	t:ne(tcp_socket.ssl_params, ssl_params)
	t:ne(tcp_socket.ssl_params.nested, ssl_params.nested)
end

return test
