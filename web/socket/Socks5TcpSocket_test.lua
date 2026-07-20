local Socks5TcpSocket = require("web.socket.Socks5TcpSocket")

local test = {}

---@class web.FakeSocks5TcpSocket
---@field responses string
---@field sent string[]
---@field connected_host string?
---@field connected_port integer?
local FakeTcpSocket = {}
FakeTcpSocket.__index = FakeTcpSocket

---@param responses string
---@return web.FakeSocks5TcpSocket
local function new_tcp_socket(responses)
	return setmetatable({responses = responses, sent = {}}, FakeTcpSocket)
end

---@param host string
---@param port integer
---@return 1
function FakeTcpSocket:connect(host, port)
	self.connected_host = host
	self.connected_port = port
	return 1
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer
function FakeTcpSocket:send(data, i, j)
	i = i or 1
	j = j or #data
	table.insert(self.sent, data:sub(i, j))
	return j
end

---@param size integer
---@return string
function FakeTcpSocket:receive(size)
	local data = self.responses:sub(1, size)
	self.responses = self.responses:sub(size + 1)
	return data
end

---@param t testing.T
function test.no_auth_domain_connect(t)
	local tcp_socket = new_tcp_socket(string.char(5, 0, 5, 0, 0, 1, 127, 0, 0, 1, 0, 80))
	local socket = Socks5TcpSocket(tcp_socket --[[@as any]], {
		host = "192.0.2.10",
		port = 1080,
	})

	local ok, err = socket:connect("example.test", 443)

	t:eq(ok, 1)
	t:eq(err, nil)
	t:eq(tcp_socket.connected_host, "192.0.2.10")
	t:eq(tcp_socket.connected_port, 1080)
	t:eq(tcp_socket.sent[1], string.char(5, 1, 0))
	t:eq(tcp_socket.sent[2], string.char(5, 1, 0, 3, 12) .. "example.test" .. string.char(1, 187))
end

---@param t testing.T
function test.username_password_authentication(t)
	local tcp_socket = new_tcp_socket(string.char(5, 2, 1, 0, 5, 0, 0, 3, 0, 0, 0))
	local socket = Socks5TcpSocket(tcp_socket --[[@as any]], {
		host = "proxy.test",
		port = 1080,
		username = "user",
		password = "pass",
	})

	t:eq(socket:connect("203.0.113.7", 80), 1)
	t:eq(tcp_socket.sent[1], string.char(5, 2, 0, 2))
	t:eq(tcp_socket.sent[2], string.char(1, 4) .. "user" .. string.char(4) .. "pass")
	t:eq(tcp_socket.sent[3], string.char(5, 1, 0, 1, 203, 0, 113, 7, 0, 80))
end

---@param t testing.T
function test.ipv6_connect(t)
	local tcp_socket = new_tcp_socket(string.char(5, 0, 5, 0, 0, 1, 127, 0, 0, 1, 0, 80))
	local socket = Socks5TcpSocket(tcp_socket --[[@as any]], {
		host = "proxy.test",
		port = 1080,
	})

	t:eq(socket:connect("2001:db8::7", 443), 1)
	t:eq(tcp_socket.sent[2], string.char(
		5, 1, 0, 4,
		0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7,
		1, 187
	))
end

---@param t testing.T
function test.connect_error_is_reported(t)
	local tcp_socket = new_tcp_socket(string.char(5, 0, 5, 5, 0, 1))
	local socket = Socks5TcpSocket(tcp_socket --[[@as any]], {
		host = "proxy.test",
		port = 1080,
	})

	local ok, err = socket:connect("example.test", 443)

	t:eq(ok, nil)
	t:eq(err, "SOCKS connection refused")
end

return test
