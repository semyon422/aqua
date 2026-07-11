local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local StringSocket = require("web.socket.StringSocket")
local util = require("web.http.util")
local test = {}

---@class web.FakeTcpSocketForHttpUtil
---@field timeout number?
---@field soc web.StringSocket?
---@field sent string[]?
local FakeTcpSocket = {}
FakeTcpSocket.__index = FakeTcpSocket

---@param timeout number
function FakeTcpSocket:settimeout(timeout)
	self.timeout = timeout
end

---@return 1
function FakeTcpSocket:connect()
	return 1
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer
function FakeTcpSocket:send(data, i, j)
	table.insert(self.sent, data)
	return #data
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return string?
---@return string?
function FakeTcpSocket:receive(pattern, prefix)
	return self.soc:receive(pattern, prefix)
end

---@param max integer
---@return string?
---@return string?
function FakeTcpSocket:receiveany(max)
	return self.soc:receiveany(max)
end

---@return 1
function FakeTcpSocket:close()
	self.closed = true
	return 1
end

---@param response string
---@return web.FakeTcpSocketForHttpUtil
local function new_tcp_socket(response)
	return setmetatable({
		soc = StringSocket(response),
		sent = {},
	}, FakeTcpSocket)
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
function test.request_download_progress(t)
	local tcp_socket = new_tcp_socket("HTTP/1.1 200 OK\r\nContent-Length: 11\r\n\r\nhello world")
	---@type table[]
	local progress = {}

	local res, err = util.request("http://example.test/path", nil, {
		tcp_socket = tcp_socket --[[@as any]],
		chunk_size = 5,
		on_download = function(downloaded, total, chunk)
			table.insert(progress, {downloaded, total, chunk})
		end,
	})

	t:eq(err, nil)
	t:eq(res.status, 200)
	t:eq(res.body, "hello world")
	t:tdeq(progress, {
		{5, 11, "hello"},
		{10, 11, " worl"},
		{11, 11, "d"},
	})
	t:assert(tcp_socket.sent[1]:find("GET /path HTTP/1.1", 1, true))
end

---@param t testing.T
function test.request_upload_chunks(t)
	local tcp_socket = new_tcp_socket("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
	---@type table[]
	local progress = {}

	local res, err = util.request("http://example.test/upload", nil, {
		tcp_socket = tcp_socket --[[@as any]],
		request_chunks = {"hello", " world"},
		on_upload = function(uploaded, total, chunk)
			table.insert(progress, {uploaded, total, chunk})
		end,
	})

	t:eq(err, nil)
	t:eq(res.body, "ok")
	t:tdeq(progress, {
		{5, nil, "hello"},
		{11, nil, " world"},
	})

	local sent = table.concat(tcp_socket.sent)
	t:assert(sent:find("POST /upload HTTP/1.1", 1, true))
	t:assert(sent:find("Transfer%-Encoding: chunked"))
	t:assert(sent:find("5\r\nhello\r\n", 1, true))
	t:assert(sent:find("6\r\n world\r\n", 1, true))
	t:assert(sent:find("0\r\n\r\n", 1, true))
end

---@param t testing.T
function test.request_does_not_mutate_options(t)
	local tcp_socket = new_tcp_socket("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
	local options = {
		tcp_socket = tcp_socket --[[@as any]],
	}

	local res, err = util.request("http://example.test/status", nil, options)

	t:eq(err, nil)
	t:eq(res.body, "ok")
	t:eq(options.client_factory, nil)
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
