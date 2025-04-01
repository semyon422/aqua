local class = require("class")
local mime = require("mime")
local Subprotocol = require("web.ws.Subprotocol")
local WebsocketFrame = require("web.ws.WebsocketFrame")

---@type {new: fun(_: string?): {final: fun(_: any, s: string): string}}
local openssl_digest = require("openssl.digest")

---@type {bytes: fun(size: integer): string}
local openssl_rand = require("openssl.rand")

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

---@return web.WebsocketState
function Websocket:getState()
	return self.state
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

---@return web.WebsocketFrame?
---@return string?
function Websocket:receive()
	local role = assert(self.role, "missing role")

	local frame = WebsocketFrame()

	local ok, err = frame:receive(self.soc, self.max_payload_len)
	if not ok then
		return nil, err
	end

	ok, err = frame:isValid(role == "server" and "client" or "server")
	if not ok then
		return nil, err
	end

	return frame
end

---@param opcode web.WebsocketOpcode
---@param payload string?
function Websocket:send(opcode, payload)
	if self.state ~= "open" then
		return nil, "invalid state"
	end

	local role = assert(self.role, "missing role")

	local frame = WebsocketFrame()
	frame.fin = true
	frame.masked = role == "client"
	frame:setOpcode(opcode)
	frame.payload = payload or ""

	local ok, err = frame:isValid(role)
	if not ok then
		return nil, err
	end

	return frame:send(self.soc)
end

---@param code integer?
---@param msg string?
function Websocket:send_close(code, msg)
	if self.close_sent then
		return nil, "close sent"
	end
	self.close_sent = true
	self.state = "closing"

	local role = assert(self.role, "missing role")

	local frame = WebsocketFrame()
	frame.fin = true
	frame.masked = role == "client"
	frame:setOpcode("close")
	frame:setClosePayload(code, msg)

	local ok, err = frame:isValid(role)
	if not ok then
		return nil, err
	end

	return frame:send(self.soc)
end

---@return web.WebsocketFrame|true? clean_close
---@return string?
function Websocket:step()
	if self.state ~= "open" then
		return nil, "invalid state"
	end

	local protocol = self.protocol

	---@type integer
	local ok

	local frame, err = self:receive()
	if not frame then
		self.state = "closed"
		return nil, err
	end

	local opcode = frame:getOpcode()
	if opcode == "continuation" then
		protocol:continuation(frame.payload, frame.fin)
	elseif opcode == "text" then
		protocol:text(frame.payload, frame.fin)
	elseif opcode == "binary" then
		protocol:binary(frame.payload, frame.fin)
	elseif opcode == "close" then
		local _code, _msg = frame:getClosePayload() -- no error for valid frames
		local code, msg = protocol:close(_code, _msg)
		if not self.close_sent then
			ok, err = self:send_close(code, msg)
			if not ok then
				return nil, err
			end
		end
		self.state = "closed"
		return true
	elseif opcode == "ping" then
		local _payload = protocol:ping(frame.payload)
		ok, err = self:send("pong", _payload)
		if not ok then
			return nil, err
		end
	elseif opcode == "pong" then
		protocol:pong(frame.payload)
	end

	return frame
end

---@return true? clean_close
---@return string?
function Websocket:loop()
	local ret, err = self:step()
	while ret do
		if ret == true then
			return true
		end
		ret, err = self:step()
	end

	---@cast err string
	return nil, err
end

return Websocket
