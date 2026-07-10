local HttpClient = require("web.http.HttpClient")

local test = {}

---@class web.FakeTcpSocketForHttpClient
---@field connected_host string?
---@field connected_port integer?
---@field sni_name string?
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

---@return 1
function FakeTcpSocket:sslwrap()
	return 1
end

---@param name string
function FakeTcpSocket:sni(name)
	self.sni_name = name
end

---@return 1
function FakeTcpSocket:sslhandshake()
	return 1
end

---@param t testing.T
function test.connect_host_preserves_url_host_for_http(t)
	local tcp_socket = setmetatable({}, FakeTcpSocket)
	local client = HttpClient(tcp_socket --[[@as any]])

	local req = client:connect("http://example.test/path?q=1", "203.0.113.10")

	t:eq(tcp_socket.connected_host, "203.0.113.10")
	t:eq(tcp_socket.connected_port, 80)
	t:eq(req.headers:get("Host"), "example.test")
	t:eq(req.uri, "/path?q=1")
end

---@param t testing.T
function test.connect_host_preserves_url_host_for_sni(t)
	local tcp_socket = setmetatable({}, FakeTcpSocket)
	local client = HttpClient(tcp_socket --[[@as any]])

	local req = client:connect("https://example.test/path", "203.0.113.10")

	t:eq(tcp_socket.connected_host, "203.0.113.10")
	t:eq(tcp_socket.connected_port, 443)
	t:eq(tcp_socket.sni_name, "example.test")
	t:eq(req.headers:get("Host"), "example.test")
end

return test
