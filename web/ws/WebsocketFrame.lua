local class = require("class")
local byte = require("byte")
local table_util = require("table_util")
local ffi = require("ffi")
local random = require("web.random")

---@class web.WebsocketFrame
---@operator call: web.WebsocketFrame
---@field masking_key string?
local WebsocketFrame = class()

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

---@param p {[integer]: integer}
---@param payload_len integer
local function xor_payload(p, payload_len)
	for i = 0, payload_len - 1 do
		p[i] = bit.bxor(p[i], p[i % 4 - 4])
	end
end

WebsocketFrame.fin = true
WebsocketFrame.rsv1 = false
WebsocketFrame.rsv2 = false
WebsocketFrame.rsv3 = false
WebsocketFrame.opcode = 0
WebsocketFrame.masked = false
WebsocketFrame.payload = ""

---@return web.WebsocketOpcode
function WebsocketFrame:getOpcode()
	return assert(OpcodeName[self.opcode])
end

---@param opcode web.WebsocketOpcode
function WebsocketFrame:setOpcode(opcode)
	self.opcode = assert(Opcode[opcode])
end

---@param endpoint "client"|"server" frame sender
---@return true?
---@return string?
function WebsocketFrame:isValid(endpoint)
	if self.rsv1 or self.rsv2 or self.rsv3 then
		return nil, "bad RSV* bits"
	end

	local opcode = self.opcode
	if opcode >= 0x3 and opcode <= 0x7 or opcode >= 0xb and opcode <= 0xf then
		return nil, "reserved opcode"
	end

	local _masked = endpoint == "client"
	if _masked ~= self.masked then
		return nil, endpoint == "server" and "frame masked" or "frame unmasked"
	end

	local masking_key = self.masking_key
	if masking_key and (type(masking_key) ~= "string" or #masking_key ~= 4) then
		return nil, "invalid masking key"
	end

	local fin = self.fin
	local payload_len = #self.payload

	if opcode == Opcode.close then
		if payload_len > 125 then
			return nil, "too long"
		elseif not fin then
			return nil, "fragmented"
		end

		local code, msg = self:getClosePayload()
		if not code and msg then
			return nil, msg
		end
	end

	return true
end

---@return integer
function WebsocketFrame:getSize()
	local payload_len = #self.payload
	local size = 2 + payload_len
	if payload_len <= 125 then
	elseif payload_len <= 65535 then
		size = size + 2
	else
		size = size + 8
	end
	if self.masked then
		size = size + 4
	end
	return size
end

function WebsocketFrame:build()
	local payload = self.payload
	local payload_len = #payload

	local frame_size = self:getSize()
	---@type {[integer]: integer}
	local buf = ffi.new("uint8_t[?]", frame_size)
	local offset = 0

	buf[0] = bit.band(self.opcode, 0x0f)
	if self.fin then
		buf[0] = bit.bor(buf[0], 0x80)
	end

	if payload_len <= 125 then
		buf[1] = payload_len
		offset = 2
	elseif payload_len <= 65535 then
		buf[1] = 126
		byte.union_be(buf + 2).u16 = payload_len
		offset = 4
	else
		buf[1] = 127
		byte.union_be(buf + 2).u64 = payload_len
		offset = 10
	end

	if self.masked then
		buf[1] = bit.bor(buf[1], 0x80)
		local masking_key = self.masking_key or random.bytes(4)
		ffi.copy(buf + offset, masking_key, 4)
		offset = offset + 4
	end

	ffi.copy(buf + offset, payload, payload_len)

	if self.masked then
		xor_payload(buf + offset, payload_len)
	end

	return ffi.string(buf, frame_size)
end

---@param soc web.ISocket
---@return integer?
---@return string?
function WebsocketFrame:send(soc)
	local frame, err = self:build()
	if not frame then
		return nil, err
	end

	local bytes, err = soc:send(frame)
	if not bytes then
		return nil, err
	end

	return bytes
end

---@param soc web.ISocket
---@param max_payload_len integer?
---@return true?
---@return string?
function WebsocketFrame:receive(soc, max_payload_len)
	local data, err = soc:receive(2)
	if not data then
		return nil, err
	end

	local byte1, byte2 = string.byte(data, 1, 2)

	self.fin = bit.band(byte1, 0x80) ~= 0

	self.rsv1 = bit.band(byte1, 0b01000000) ~= 0
	self.rsv2 = bit.band(byte1, 0b00100000) ~= 0
	self.rsv3 = bit.band(byte1, 0b00010000) ~= 0

	self.opcode = bit.band(byte1, 0x0f)

	self.masked = bit.band(byte2, 0x80) ~= 0

	local payload_len = bit.band(byte2, 0x7f)

	if payload_len == 126 then
		data, err = soc:receive(2)
		if not data then
			return nil, err
		end
		payload_len = bit.bor(bit.lshift(data:byte(1), 8), data:byte(2))
	elseif payload_len == 127 then
		data, err = soc:receive(8)
		if not data then
			return nil, err
		end
		payload_len = tonumber(byte.union_be(data).u64)
	end

	---@cast payload_len integer

	if max_payload_len and payload_len > max_payload_len then
		return nil, "too long"
	end

	local rest = payload_len
	if self.masked then
		rest = rest + 4
	end

	data = ""
	if rest > 0 then
		data, err = soc:receive(rest)
		if not data then
			return nil, err
		end
	end

	local buf_len = #data
	---@type {[integer]: integer}
	local buf = ffi.new("uint8_t[?]", buf_len)
	ffi.copy(buf, data, buf_len)

	local offset = 0
	if self.masked then
		offset = 4
		self.masking_key = ffi.string(buf, 4)
		xor_payload(buf + offset, payload_len)
	end

	self.payload = ffi.string(buf + offset, payload_len)

	return true
end

---@param code integer?
---@param msg string?
function WebsocketFrame:setClosePayload(code, msg)
	if not code then
		self.payload = ""
		return
	end

	assert(type(code) == "number" and code >= 0 and code <= 0x7fff, "bad status code")
	local code_string = string.char(bit.band(bit.rshift(code, 8), 0xff), bit.band(code, 0xff))
	self.payload = code_string .. (msg or "")
end

---@return integer?
---@return string?
function WebsocketFrame:getClosePayload()
	local payload = self.payload
	local payload_len = #payload

	if payload_len == 0 then
		return
	end

	if payload_len < 2 then
		return nil, "invalid close payload"
	end

	local code = bit.lshift(payload:byte(1), 8) + payload:byte(2)
	local msg = payload:sub(3)

	return code, msg
end

return WebsocketFrame
