local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local util = require("web.http.util")
local test = {}

---@class web.FakeTcpSocketForHttpUtil
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

	local configured = util.tcp({
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

---@param t testing.T
function test.client_uses_configured_tcp_socket(t)
	local tcp_socket = setmetatable({}, FakeTcpSocket)

	local client = util.client({
		tcp_socket = tcp_socket --[[@as any]],
		timeout = 3,
	})

	t:eq(client.tcp_soc, tcp_socket)
	t:eq(tcp_socket.timeout, 3)
end

---@param t testing.T
function test.tcp_uses_scheduler_transport(t)
	local scheduler = CosocketScheduler()

	local tcp_socket = util.tcp({scheduler = scheduler})

	t:eq(tcp_socket.scheduler, scheduler)
end

---@param t testing.T
function test.parse_content_disposition(t)
	local s = "attachment; filename=\"test.zip\"; size=123"
	local cd = util.parse_content_disposition(s)
	t:eq(cd[1], "attachment")
	t:eq(cd.filename, "test.zip")
	t:eq(cd.size, "123")

	local s2 = "inline"
	local cd2 = util.parse_content_disposition(s2)
	t:eq(cd2[1], "inline")

	local s3 = "form-data; name=\"file\"; filename=\"photo.jpg\""
	local cd3 = util.parse_content_disposition(s3)
	t:eq(cd3[1], "form-data")
	t:eq(cd3.name, "file")
	t:eq(cd3.filename, "photo.jpg")

	-- RFC 8187
	local s4 = "attachment; filename*=UTF-8''%d1%82%d0%b5%d1%81%d1%82%2ezip"
	local cd4 = util.parse_content_disposition(s4)
	t:eq(cd4[1], "attachment")
	t:eq(cd4.filename, "тест.zip")
end

---@param t testing.T
function test.encode_content_disposition(t)
	local cd = {"attachment", filename = "test.zip", size = 123}
	local s = util.encode_content_disposition(cd)
	-- dpairs sorts alphabetically: filename, size
	t:eq(s, "attachment; filename=\"test.zip\"; size=\"123\"")

	local cd2 = {"form-data", name = "file"}
	local s2 = util.encode_content_disposition(cd2)
	t:eq(s2, "form-data; name=\"file\"")

	-- RFC 8187
	local cd3 = {"attachment", filename = "тест.zip"}
	local s3 = util.encode_content_disposition(cd3)
	t:eq(s3, "attachment; filename*=UTF-8''%d1%82%d0%b5%d1%81%d1%82%2ezip")
end

return test
