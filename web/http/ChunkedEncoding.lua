local ISocket = require("web.socket.ISocket")
local Headers = require("web.http.Headers")

-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Transfer-Encoding
-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Trailer
-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/TE

---@class web.ChunkedEncoding: web.ISocket
---@operator call: web.ChunkedEncoding
local ChunkedEncoding = ISocket + {}

---@param err string?
---@return "timeout"|"closed early"
local function closed_early_or_timeout(err)
	return err == "timeout" and "timeout" or "closed early"
end

---@param soc web.IExtendedSocket
function ChunkedEncoding:new(soc)
	self.soc = soc
	self.headers = Headers()

	self.receive_closed = false
	self.send_closed = false

	---@type "size"|"data"|"trailer"|"closed"
	self.state = "size"
end

---@private
---@return 1?
---@return "closed early"|"timeout"|"invalid chunk size"?
function ChunkedEncoding:receive_size()
	local data, err, _ = self.soc:receive("*l")

	if not data then
		return nil, closed_early_or_timeout(err)
	end

	local size = tonumber(data:gsub(";.*", ""), 16)
	if not size then
		return nil, "invalid chunk size"
	end
	self.chunk_size = size

	self.state = size > 0 and "data" or "trailer"

	return 1
end

---@private
---@return string?
---@return "closed early"|"timeout"?
---@return string?
function ChunkedEncoding:receive_data(_size)
	local size = math.min(_size, self.chunk_size)
	local data, err, _ = self.soc:receive(size)

	if not data then
		return nil, closed_early_or_timeout(err)
	end

	if #data == self.chunk_size then
		local line, _err, _ = self.soc:receive("*l")
		if not line then
			return nil, closed_early_or_timeout(_err)
		end
		self.state = "size"
	end

	self.chunk_size = self.chunk_size - #data

	return data
end

---@param size integer
---@return string?
---@return "closed"|"timeout"|"closed early"|"invalid chunk size"|"malformed headers"?
function ChunkedEncoding:receiveany(size)
	if self.receive_closed then
		return nil, "closed"
	end
	if self.state == "size" then
		local ok, err = self:receive_size()
		if not ok then
			return nil, err
		end
	end
	if self.state == "data" then
		return self:receive_data(size)
	end
	if self.state == "trailer" then
		local ok, err = self.headers:receive(self.soc)
		if not ok then
			return nil, closed_early_or_timeout(err)
		end
		self.receive_closed = true
		return nil, "closed"
	end
end

---@param size integer
---@return string?
---@return "closed"|"timeout"|"invalid chunk size"|"malformed headers"?
---@return string?
function ChunkedEncoding:receive(size)
	-- ExtendedSocket should be used for this
	error("not implemented")
end

---@param chunk string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function ChunkedEncoding:send(chunk, i, j)
	assert((not i or i == 1) and (not j or j == #chunk), "not implemented")
	if self.send_closed then
		return nil, "closed", 0
	end
	if #chunk > 0 then
		local last_byte, err, _ = self.soc:send(("%X\r\n%s\r\n"):format(#chunk, chunk))
		if last_byte then
			return #chunk
		end
		return nil, err, 0
	end
	local last_byte, err, _ = self.soc:send("0\r\n")
	if not last_byte then
		return nil, err, 0
	end
	local ok, err = self.headers:send(self.soc)
	if not ok then
		return nil, err, 0
	end
	self.send_closed = true
	return 0
end

return ChunkedEncoding
