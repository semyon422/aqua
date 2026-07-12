local HttpStream = require("web.http.HttpStream")
local StringSocket = require("web.socket.StringSocket")

local test = {}

---@class web.FakeTcpSocketForHttpStream
---@field soc web.StringSocket
---@field sent string[]
---@field closed boolean?
local FakeTcpSocket = {}
FakeTcpSocket.__index = FakeTcpSocket

---@param response string
---@return web.FakeTcpSocketForHttpStream
local function new_tcp_socket(response)
	return setmetatable({
		soc = StringSocket(response),
		sent = {},
	}, FakeTcpSocket)
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

---@param t testing.T
function test.duplex_upload_and_download(t)
	local tcp_socket = new_tcp_socket("HTTP/1.1 200 OK\r\nContent-Length: 11\r\n\r\nhello world")
	---@type table[]
	local upload_progress = {}
	---@type table[]
	local download_progress = {}
	local stream = HttpStream({
		tcp_socket = tcp_socket --[[@as any]],
		chunk_size = 5,
		on_upload = function(uploaded, total, chunk)
			table.insert(upload_progress, {uploaded, total, chunk})
		end,
		on_download = function(downloaded, total, chunk)
			table.insert(download_progress, {downloaded, total, chunk})
		end,
	})

	t:tdeq({stream:connect("http://example.test/upload")}, {true})
	t:tdeq({stream:startUpload()}, {true})
	t:tdeq({stream:sendChunk("hello")}, {5})

	local chunk, err, partial = stream:receiveChunk()
	t:tdeq({chunk, err, partial}, {"hello"})
	t:eq(stream.upload_finished, false)

	t:tdeq({stream:sendChunk(" world")}, {6})
	t:tdeq({stream:finishUpload()}, {0})
	t:tdeq({stream:receiveChunk()}, {" worl"})
	t:tdeq({stream:receiveChunk()}, {"d"})

	t:tdeq(upload_progress, {
		{5, nil, "hello"},
		{11, nil, " world"},
	})
	t:tdeq(download_progress, {
		{5, 11, "hello"},
		{10, 11, " worl"},
		{11, 11, "d"},
	})

	local sent = table.concat(tcp_socket.sent)
	t:assert(sent:find("POST /upload HTTP/1.1", 1, true))
	t:assert(sent:find("Transfer%-Encoding: chunked"))
	t:assert(sent:find("5\r\nhello\r\n", 1, true))
	t:assert(sent:find("6\r\n world\r\n", 1, true))
	t:assert(sent:find("0\r\n\r\n", 1, true))
end

---@param t testing.T
function test.known_length_upload(t)
	local tcp_socket = new_tcp_socket("HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n")
	local stream = HttpStream({
		tcp_socket = tcp_socket --[[@as any]],
		request_length = 5,
	})

	t:tdeq({stream:connect("http://example.test/upload")}, {true})
	t:tdeq({stream:sendChunk("hello")}, {5})
	t:tdeq({stream:finishUpload()}, {0})

	local sent = table.concat(tcp_socket.sent)
	t:assert(sent:find("Content%-Length: 5"))
	t:assert(not sent:find("Transfer%-Encoding"))
end

---@param t testing.T
function test.get_request_headers(t)
	local tcp_socket = new_tcp_socket("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
	local stream = HttpStream({
		tcp_socket = tcp_socket --[[@as any]],
		headers = {
			Accept = "text/plain",
		},
	})

	t:tdeq({stream:connect("http://example.test/status")}, {true})
	t:tdeq({stream:sendHeaders()}, {true})
	t:tdeq({stream:receiveChunk()}, {"ok"})

	local sent = table.concat(tcp_socket.sent)
	t:assert(sent:find("GET /status HTTP/1.1", 1, true))
	t:assert(sent:find("Accept: text/plain", 1, true))
end

---@param t testing.T
function test.cancel_closes_socket_and_stops_operations(t)
	local tcp_socket = new_tcp_socket("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
	local close_count = 0
	local stream = HttpStream({
		tcp_socket = tcp_socket --[[@as any]],
		on_close = function()
			close_count = close_count + 1
		end,
	})

	t:tdeq({stream:connect("http://example.test/status")}, {true})
	stream:cancel("manual cancel")
	t:eq(stream:isCanceled(), true)
	t:eq(stream:getCancelError(), "manual cancel")
	t:eq(tcp_socket.closed, true)
	t:eq(close_count, 1)

	t:tdeq({stream:sendHeaders()}, {nil, "manual cancel"})
	t:tdeq({stream:receiveChunk()}, {nil, "manual cancel", ""})
	t:tdeq({stream:close()}, {1})
	t:eq(close_count, 1)
end

---@param t testing.T
function test.cancel_defaults_to_canceled(t)
	local tcp_socket = new_tcp_socket("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
	local stream = HttpStream({
		tcp_socket = tcp_socket --[[@as any]],
	})

	t:tdeq({stream:connect("http://example.test/status")}, {true})
	stream:cancel()

	t:tdeq({stream:sendHeaders()}, {nil, "canceled"})
end

---@param t testing.T
function test.cancel_during_connect_closes_client(t)
	local close_count = 0
	local stream
	stream = HttpStream({
		client_factory = function()
			return {
				connect = function()
					stream:cancel("connect canceled")
					return {}, {}
				end,
				close = function()
					close_count = close_count + 1
				end,
			}
		end,
	})

	t:tdeq({stream:connect("http://example.test/status")}, {nil, "connect canceled"})
	t:eq(close_count, 1)
	t:eq(stream.client, nil)
end

return test
