local Websocket = require("web.ws.Websocket")
local Request = require("web.http.Request")
local Response = require("web.http.Response")
local StringSocket = require("web.socket.StringSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")

local function req_res(soc)
	local req = Request(soc)
	local res = Response(soc)
	return req, res
end

local test = {}

---@param t testing.T
function test.handshake(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local req, res = req_res(soc)
	local ws = Websocket(soc, req, res)

	local key_t = t:assert(ws:req_send())
	req:new(soc) -- reset request headers
	local key_proto_t = t:assert(ws:req_receive())
	t:assert(ws:res_send(key_proto_t.key, key_proto_t.protocols[1]))
	t:assert(ws:res_receive(key_t.key))
end

---@param t testing.T
function test.client_to_server(t)
	local str_soc_cs = StringSocket()
	local str_soc_sc = str_soc_cs:split()

	local client = Websocket(str_soc_cs, nil, nil, "client")
	client.max_payload_len = 1e6
	client.state = "open"

	local server = Websocket(str_soc_sc, nil, nil, "server")
	server.max_payload_len = 1e6
	server.state = "open"

	local long_msg_1 = ("a"):rep(1000)
	local long_msg_2 = ("a"):rep(100000)

	t:assert(server:send("text", "helloworld"))
	t:assert(server:send("text", long_msg_1))
	t:assert(server:send("text", long_msg_2))
	t:assert(server:send("binary", "\0\1\2\3"))
	t:assert(server:send("ping", "ping msg"))
	t:assert(server:send("pong", "pong msg"))
	-- t:assert(server:send_close(999, "close msg"))
	-- t:assert(server:send_close(999, ""))

	t:assert(client:send("text", "helloworld", true))
	t:assert(client:send("text", long_msg_1, true))
	t:assert(client:send("text", long_msg_2, true))
	t:assert(client:send("binary", "\0\1\2\3", true))
	t:assert(client:send("ping", "ping msg", true))
	t:assert(client:send("pong", "pong msg", true))
	-- t:assert(client:send_close(999, "close msg", true))
	-- t:assert(client:send_close(999, "", true))

	---@param ws web.Websocket
	local function receive(ws)
		local frame, err = ws:receive()
		if not frame then
			return nil, err
		end
		return frame.payload, frame:getOpcode(), frame.fin
	end

	t:tdeq({receive(client)}, {"helloworld", "text", true})
	t:tdeq({receive(client)}, {long_msg_1, "text", true})
	t:tdeq({receive(client)}, {long_msg_2, "text", true})
	t:tdeq({receive(client)}, {"\0\1\2\3", "binary", true})
	t:tdeq({receive(client)}, {"ping msg", "ping", true})
	t:tdeq({receive(client)}, {"pong msg", "pong", true})
	-- t:tdeq({client:receive()}, {"close msg", "close", 999})
	-- t:tdeq({client:receive()}, {"", "close", 999})

	t:tdeq({receive(server)}, {"helloworld", "text", true})
	t:tdeq({receive(server)}, {long_msg_1, "text", true})
	t:tdeq({receive(server)}, {long_msg_2, "text", true})
	t:tdeq({receive(server)}, {"\0\1\2\3", "binary", true})
	t:tdeq({receive(server)}, {"ping msg", "ping", true})
	t:tdeq({receive(server)}, {"pong msg", "pong", true})
	-- t:tdeq({server:receive()}, {"close msg", "close", 999})
	-- t:tdeq({server:receive()}, {"", "close", 999})
end

---@param t testing.T
function test.connect_and_close_by_server(t)
	local str_soc_cs = StringSocket()
	local str_soc_sc = str_soc_cs:split()

	local soc_cs = ExtendedSocket(str_soc_cs)
	soc_cs.cosocket = true

	local soc_sc = ExtendedSocket(str_soc_sc)
	soc_sc.cosocket = true

	local req, res = req_res(soc_cs)
	local client = Websocket(soc_cs, req, res, "client")

	local state_client = 0
	local co_client = coroutine.create(function()
		t:assert(client:handshake())
		state_client = 1
		t:assert(client:loop())
		state_client = 2
	end)

	coroutine.resume(co_client)
	t:eq(state_client, 0)

	local req, res = req_res(soc_sc)
	local server = Websocket(soc_sc, req, res, "server")

	local state_server = 0
	local co_server = coroutine.create(function()
		t:assert(server:handshake())
		state_server = 1
		t:assert(server:loop())
		state_server = 2
	end)

	coroutine.resume(co_server)
	coroutine.resume(co_client)

	t:eq(state_server, 1)
	t:eq(state_client, 1)

	t:assert(server:send_close(1000, ""))

	coroutine.resume(co_client)
	t:eq(state_client, 2)

	coroutine.resume(co_server)
	t:eq(state_server, 2)
end

-- ---@param t testing.T
-- function test.client(t)
-- 	local WebsocketClient = require("web.ws.WebsocketClient")
-- 	local LsTcpSocket = require("web.luasocket.LsTcpSocket")
-- 	local tcp_soc = LsTcpSocket(4)

-- 	local client = WebsocketClient(tcp_soc)
-- 	local req, res = client:connect("ws://localhost:8180/ws")

-- 	local ws = Websocket(tcp_soc, req, res, "client")

-- 	function ws.protocol:text(payload)
-- 		print("received", payload)
-- 	end

-- 	t:assert(ws:handshake())

-- 	ws:send("text", "data")

-- 	t:assert(ws:loop())
-- end

return test
