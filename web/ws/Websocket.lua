local class = require("class")
local mime = require("mime")
local bit = require("bit")
local ffi = require("ffi")
local byte = require("byte")
local table_util = require("table_util")
local openssl_digest = require("openssl.digest")
local openssl_rand = require("openssl.rand")
local Subprotocol = require("web.ws.Subprotocol")

-- https://25thandclement.com/~william/projects/luaossl.pdf
-- https://datatracker.ietf.org/doc/html/rfc6455

---@param s string
---@return string
local function sha1(s)
	return openssl_digest.new("sha1"):final(s)
end

---@param key string
---@return string
local function gen_accept(key)
	return (mime.b64(sha1(key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")))
end

---@enum (key) web.WebsocketState
local State = {
	connecting = 0,
	open = 1,
	closing = 2,
	closed = 3,
}

---@enum (key) web.WebsocketOpcode
local Opcode = {
	continuation = 0x0,
	text = 0x1,
	binary = 0x2,
	close = 0x8,
	ping = 0x9,
	pong = 0xa,
}

---@type {[integer]: web.WebsocketOpcode}
local OpcodeName = table_util.invert(Opcode)

---@class web.Websocket
---@operator call: web.Websocket
---@field state web.WebsocketState
local Websocket = class()

Websocket.max_payload_len = 2 ^ 16

---@param soc web.ISocket
---@param req web.IRequest
---@param res web.IResponse
---@param role "server"|"client"?
---@param protocol web.Subprotocol
function Websocket:new(soc, req, res, role, protocol)
	self.soc = soc
	self.req = req
	self.res = res
	self.role = role
	self.state = "connecting"
	self.protocol = protocol or Subprotocol(self)
end

---@return {key: string, protocols: string[]}?
---@return string?
function Websocket:req_receive()
	local req = self.req

	req:receive_headers()

	local upgrade = req.headers:get("Upgrade")
	if not upgrade or upgrade:lower() ~= "websocket" then
		return nil, "bad upgrade header"
	end

	local connection = req.headers:get("Connection")
	if not connection or not connection:lower():find("upgrade") then
		return nil, "bad connection header"
	end

	local ws_key = req.headers:get("Sec-WebSocket-Key")
	if not ws_key then
		return nil, "bad ws key header"
	end

	local ws_version = req.headers:get("Sec-WebSocket-Version")
	if not ws_version or tonumber(ws_version) ~= 13 then
		return nil, "bad ws version header"
	end

	return {
		key = ws_key,
		protocols = req.headers:getTable("Sec-WebSocket-Protocol"),
	}
end

---@param key string
---@param protocol string?
---@return true?
---@return string?
function Websocket:res_send(key, protocol)
	local res = self.res

	res.headers:set("Upgrade", "websocket")
	res.headers:set("Connection", "Upgrade")
	res.headers:set("Sec-WebSocket-Accept", gen_accept(key))
	if protocol then
		res.headers:set("Sec-WebSocket-Protocol", protocol)
	end

	res.status = 101

	local ok, err = res:send_headers()
	if not ok then
		return nil, err
	end

	self.state = "open"

	return true
end

---@return {key: string}?
---@return string?
function Websocket:req_send()
	local req = self.req

	local ws_key = mime.b64(openssl_rand.bytes(16))

	req.headers:set("Upgrade", "websocket")
	req.headers:set("Connection", "Upgrade")
	req.headers:set("Sec-WebSocket-Key", ws_key)
	req.headers:set("Sec-WebSocket-Version", 13)

	local ok, err = req:send_headers()
	if not ok then
		return nil, err
	end

	return {
		key = ws_key,
	}
end

---@param key string
---@return true?
---@return string?
function Websocket:res_receive(key)
	local res = self.res

	res:receive_headers()

	if res.status ~= 101 then
		return nil, "bad status"
	end

	local upgrade = res.headers:get("Upgrade")
	if not upgrade or upgrade:lower() ~= "websocket" then
		return nil, "bad upgrade header"
	end

	local connection = res.headers:get("Connection")
	if not connection or not connection:lower():find("upgrade") then
		return nil, "bad connection header"
	end

	local ws_accept = res.headers:get("Sec-WebSocket-Accept")
	if not ws_accept or ws_accept ~= gen_accept(key) then
		return nil, "bad ws accept header"
	end

	self.state = "open"

	return true
end

---@return true?
---@return string?
function Websocket:handshake()
	local role = assert(self.role, "missing role")

	if role == "server" then
		local key_proto_t, err = self:req_receive()
		if not key_proto_t then
			return nil, err
		end

		local ok, err = self:res_send(key_proto_t.key, key_proto_t.protocols[1])
		if not ok then
			return nil, err
		end
	elseif role == "client" then
		local key_t, err = self:req_send()
		if not key_t then
			return nil, err
		end

		local ok, err = self:res_receive(key_t.key)
		if not ok then
			return nil, err
		end
	end

	self.state = "open"

	return true
end

---@param payload_len integer
---@param masking boolean?
local function get_frame_len(payload_len, masking)
	local frame_len = 2 + payload_len
	if payload_len <= 125 then
	elseif payload_len <= 65535 then
		frame_len = frame_len + 2
	else
		frame_len = frame_len + 8
	end
	if masking then
		frame_len = frame_len + 4
	end
	return frame_len
end

---@param fin boolean
---@param opcode integer
---@param payload string
---@param masking boolean?
local function build_frame(fin, opcode, payload, masking)
	local payload_len = #payload

	local frame_len = get_frame_len(payload_len, masking)
	---@type {[integer]: integer}
	local buf = ffi.new("uint8_t[?]", frame_len)
	local offset = 0

	buf[0] = bit.band(opcode, 0x0f)
	if fin then
		buf[0] = bit.bor(buf[0], 0x80)
	end

	if payload_len <= 125 then
		buf[1] = payload_len
		offset = 2
	elseif payload_len <= 65535 then
		buf[1] = 126
		byte.write_uint16_be(buf + 2, payload_len)
		offset = 4
	else
		buf[1] = 127
		byte.write_uint64_be(buf + 2, payload_len)
		offset = 10
	end

	if masking then
		buf[1] = bit.bor(buf[1], 0x80)
		ffi.copy(buf + offset, openssl_rand.bytes(4), 4)
		offset = offset + 4
	end

	ffi.copy(buf + offset, payload, payload_len)

	if masking then
		---@type {[integer]: integer}
		local p = buf + offset
		for i = 0, payload_len - 1 do
			p[i] = bit.bxor(p[i], p[i % 4 - 4])
		end
	end

	return ffi.string(buf, frame_len)
end

---@return string?
---@return web.WebsocketOpcode?
---@return string|integer|boolean?
function Websocket:receive()
	local role = assert(self.role, "missing role")
	local soc = self.soc
	local _masked = role == "server"

	local data, err = soc:receive(2)
	if not data then
		return nil, nil, err
	end

	local byte1, byte2 = string.byte(data, 1, 2)
	local fin = bit.band(byte1, 0x80) ~= 0

	if bit.band(byte1, 0x70) ~= 0 then
		return nil, nil, "bad RSV* bits"
	end

	local opcode = bit.band(byte1, 0x0f)

	if opcode >= 0x3 and opcode <= 0x7 or opcode >= 0xb and opcode <= 0xf then
		return nil, nil, "reserved opcode"
	end

	local masked = bit.band(byte2, 0x80) ~= 0

	if _masked ~= masked then
		return nil, nil, role == "server" and "frame unmasked" or "frame masked"
	end

	local payload_len = bit.band(byte2, 0x7f)

	if payload_len == 126 then
		data, err = soc:receive(2)
		if not data then
			return nil, nil, err
		end
		payload_len = bit.bor(bit.lshift(data:byte(1), 8), data:byte(2))
	elseif payload_len == 127 then
		data, err = soc:receive(8)
		if not data then
			return nil, nil, err
		end
		payload_len = tonumber(byte.read_uint64_be(data))
	end

	if bit.band(opcode, 0x8) ~= 0 and not (payload_len <= 125 and fin) then
		return nil, nil, "too long or fragmented control frame"
	end

	if payload_len > self.max_payload_len then
		return nil, nil, "too long"
	end

	local rest = payload_len
	if masked then
		rest = rest + 4
	end

	data = ""
	if rest > 0 then
		data, err = soc:receive(rest)
		if not data then
			return nil, nil, err
		end
	end

	local buf_len = #data
	---@type {[integer]: integer}
	local buf = ffi.new("uint8_t[?]", buf_len)
	ffi.copy(buf, data, buf_len)

	local offset = 0
	if masked then
		offset = 4
		---@type {[integer]: integer}
		local p = buf + 4
		for i = 0, payload_len - 1 do
			p[i] = bit.bxor(p[i], p[i % 4 - 4])
		end
	end

	if opcode == Opcode.close then
		if payload_len > 0 then
			if payload_len < 2 then
				return nil, nil, "invalid close payload"
			end

			local code = byte.read_uint16_be(buf + offset)
			local msg = ffi.string(buf + offset + 2, payload_len - 2)

			return msg, "close", code
		end

		return "", "close", nil
	end

	local msg = ffi.string(buf + offset, payload_len)

	return msg, OpcodeName[opcode], fin
end

---@param fin boolean
---@param opcode integer
---@param payload string?
function Websocket:send_frame(fin, opcode, payload)
	local role = assert(self.role, "missing role")
	local soc = self.soc
	local masking = role == "client"
	payload = payload or ""

	if bit.band(opcode, 0x8) ~= 0 then
		assert(#payload <= 125 and fin)
	end

	local frame, err = build_frame(fin, opcode, payload, masking)

	if not frame then
		return nil, err
	end

	local bytes, err = soc:send(frame)
	if not bytes then
		return nil, err
	end
	return bytes
end

---@param opcode web.WebsocketOpcode
---@param payload string?
function Websocket:send(opcode, payload)
	if self.state ~= "open" then
		return nil, "invalid state"
	end
	local oc = assert(Opcode[opcode])
	return self:send_frame(true, oc, payload)
end

---@param code integer?
---@param msg string?
function Websocket:send_close(code, msg)
	if self.close_sent then
		return nil, "close sent"
	end
	self.close_sent = true
	self.state = "closing"
	local payload = ""
	if code then
		msg = msg or ""
		assert(type(code) == "number" and code <= 0x7fff, "bad status code")
		payload = string.char(bit.band(bit.rshift(code, 8), 0xff), bit.band(code, 0xff)) .. msg
	end
	return self:send_frame(true, Opcode.close, payload)
end

---@return true? clean_close
---@return string?
function Websocket:_loop()
	local protocol = self.protocol

	local payload, opcode, err = self:receive()
	while payload do
		if opcode == "continuation" then
			---@cast err boolean
			protocol:continuation(payload, err)
		elseif opcode == "text" then
			---@cast err boolean
			protocol:text(payload, err)
		elseif opcode == "binary" then
			protocol:binary(payload, err)
		elseif opcode == "close" then
			---@cast err integer
			local code, _payload = protocol:close(err, err and payload or nil)
			if not self.close_sent then
				local ok, err = self:send_close(code, _payload)
				if not ok then
					return nil, err
				end
			end
			self.state = "closed"
			return true
		elseif opcode == "ping" then
			local _payload = protocol:ping(payload)
			local ok, err = self:send("pong", _payload)
			if not ok then
				return nil, err
			end
		elseif opcode == "pong" then
			protocol:pong(payload)
		end
		payload, opcode, err = self:receive()
	end

	---@cast err string
	return nil, err
end

---@return true? clean_close
---@return string?
function Websocket:loop()
	local ok, err = self:_loop()
	if not ok then
		self.failed = true
	end
	return ok, err
end

return Websocket
