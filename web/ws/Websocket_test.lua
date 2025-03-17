local Websocket = require("web.ws.Websocket")
local Request = require("web.http.Request")
local Response = require("web.http.Response")
local StringSocket = require("web.socket.StringSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")

local test = {}

---@param t testing.T
function test.handshake(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local req = Request(soc)
	local res = Response(soc)
	req.wrap = false
	res.wrap = false

	local ws = Websocket(req, res)

	local key_t = t:assert(ws:req_send())
	req:new(soc) -- reset request headers
	local key_proto_t = t:assert(ws:req_receive())
	t:assert(ws:res_send(key_proto_t.key, key_proto_t.protocols[1]))
	t:assert(ws:res_receive(key_t.key))
end

---@param t testing.T
function test.client_to_server(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local req = Request(soc)
	local res = Response(soc)
	req.wrap = false
	res.wrap = false

	local ws = Websocket(req, res)
	ws.role = "client"

	local long_msg_1 = ("a"):rep(1000)
	local long_msg_2 = ("a"):rep(100000)

	t:assert(ws:send("text", "helloworld"))
	t:assert(ws:send("text", long_msg_1))
	t:assert(ws:send("text", long_msg_2))
	t:assert(ws:send("binary", "\0\1\2\3"))
	t:assert(ws:send("ping", "ping msg"))
	t:assert(ws:send("pong", "pong msg"))
	t:assert(ws:send_close(999, "close msg"))
	t:assert(ws:send_close(999, ""))

	t:assert(ws:send("text", "helloworld", true))
	t:assert(ws:send("text", long_msg_1, true))
	t:assert(ws:send("text", long_msg_2, true))
	t:assert(ws:send("binary", "\0\1\2\3", true))
	t:assert(ws:send("ping", "ping msg", true))
	t:assert(ws:send("pong", "pong msg", true))
	t:assert(ws:send_close(999, "close msg", true))
	t:assert(ws:send_close(999, "", true))

	ws.role = "server"

	t:tdeq({ws:receive_frame(1e6)}, {"helloworld", "text", nil})
	t:tdeq({ws:receive_frame(1e6)}, {long_msg_1, "text", nil})
	t:tdeq({ws:receive_frame(1e6)}, {long_msg_2, "text", nil})
	t:tdeq({ws:receive_frame(1e6)}, {"\0\1\2\3", "binary", nil})
	t:tdeq({ws:receive_frame(1e6)}, {"ping msg", "ping", nil})
	t:tdeq({ws:receive_frame(1e6)}, {"pong msg", "pong", nil})
	t:tdeq({ws:receive_frame(1e6)}, {"close msg", "close", 999})
	t:tdeq({ws:receive_frame(1e6)}, {"", "close", 999})

	t:tdeq({ws:receive_frame(1e6)}, {"helloworld", "text", nil})
	t:tdeq({ws:receive_frame(1e6)}, {long_msg_1, "text", nil})
	t:tdeq({ws:receive_frame(1e6)}, {long_msg_2, "text", nil})
	t:tdeq({ws:receive_frame(1e6)}, {"\0\1\2\3", "binary", nil})
	t:tdeq({ws:receive_frame(1e6)}, {"ping msg", "ping", nil})
	t:tdeq({ws:receive_frame(1e6)}, {"pong msg", "pong", nil})
	t:tdeq({ws:receive_frame(1e6)}, {"close msg", "close", 999})
	t:tdeq({ws:receive_frame(1e6)}, {"", "close", 999})
end

return test
