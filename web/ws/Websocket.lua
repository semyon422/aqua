local class = require("class")
local mime = require("mime")
local bit = require("bit")
local ffi = require("ffi")
local byte = require("byte")
local table_util = require("table_util")
local openssl_digest = require("openssl.digest")
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
local Websocket = class()

---@param req web.IRequest
---@param res web.IResponse
---@param role "server"|"client"
function Websocket:new(req, res, role)
	self.req = req
	self.res = res
	self.role = role
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
---@param protocol string
---@return true?
---@return string?
function Websocket:res_send(key, protocol)
	local res = self.res

	res.headers:set("Upgrade", "websocket")
	res.headers:set("Connection", "Upgrade")
	res.headers:set("Sec-WebSocket-Protocol", protocol)
	res.headers:set("Sec-WebSocket-Accept", gen_accept(key))

	res.status = 101

	local ok, err = res:send_headers()
	if not ok then
		return nil, err
	end

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

---@param max_payload_len integer
---@param force_masking boolean?
---@return string?
---@return web.WebsocketOpcode?
---@return string|integer?
function Websocket:receive_frame(max_payload_len, force_masking)
	local soc = self.role == "server" and self.req or self.res

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

	if force_masking and not masked then
		return nil, nil, "frame unmasked"
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

	if payload_len > max_payload_len then
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

	return msg, OpcodeName[opcode], not fin and "again" or nil
end

---@param fin boolean
---@param opcode integer
---@param payload string
---@param masking boolean?
function Websocket:send_frame(fin, opcode, payload, masking)
	local soc = self.role == "client" and self.req or self.res

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
---@param text string
---@param masking boolean?
function Websocket:send(opcode, text, masking)
	local oc = assert(Opcode[opcode])
	return self:send_frame(true, oc, text, masking)
end

---@param code integer?
---@param msg string?
---@param masking boolean?
function Websocket:send_close(code, msg, masking)
	local payload = ""
	if code then
		msg = msg or ""
		assert(type(code) == "number" and code <= 0x7fff, "bad status code")
		payload = string.char(bit.band(bit.rshift(code, 8), 0xff), bit.band(code, 0xff)) .. msg
	end
	return self:send("close", payload, masking)
end

return Websocket
