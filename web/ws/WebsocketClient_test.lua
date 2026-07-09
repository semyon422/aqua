local WebsocketClient = require("web.ws.WebsocketClient")

local test = {}

---@class web.FakeTcpSocket
---@field connected_host string?
---@field connected_port integer?
local FakeTcpSocket = {}
FakeTcpSocket.__index = FakeTcpSocket

---@param host string
---@param port integer
---@return 1
function FakeTcpSocket:connect(host, port)
	self.connected_host = host
	self.connected_port = port
	return 1
end

---@param data string
---@return integer
function FakeTcpSocket:send(data)
	self.sent_data = data
	return #data
end

---@param size integer
---@return string?
---@return string?
function FakeTcpSocket:receive(size)
	return nil, "stop"
end

---@param t testing.T
function test.connect_host_keeps_url_host_header(t)
	local tcp_socket = setmetatable({}, FakeTcpSocket)
	local client = WebsocketClient(tcp_socket --[[@as any]])

	local re = t:assert(client:connect("ws://example.test:1234/socket", "127.0.0.1"))

	t:eq(tcp_socket.connected_host, "127.0.0.1")
	t:eq(tcp_socket.connected_port, 1234)
	t:eq(re.req.headers:get("Host"), "example.test")
end

return test
