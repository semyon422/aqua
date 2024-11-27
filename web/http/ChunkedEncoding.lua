local ISocket = require("web.socket.ISocket")
local Headers = require("web.http.Headers")

-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Transfer-Encoding
-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Trailer

---@class web.ChunkedEncoding: web.ISocket
---@operator call: web.ChunkedEncoding
local ChunkedEncoding = ISocket + {}

---@param soc web.IExtendedSocket
function ChunkedEncoding:new(soc)
	self.soc = soc
	self.headers = Headers(soc)

	---@type "size"|"data"|"trailer"
	self.state = "size"
end

---@private
---@return true?
---@return "closed"|"timeout"|"invalid chunk size"?
function ChunkedEncoding:receive_size()
	local data, err, _ = self.soc:receive("*l")
	if not data then
		return nil, err
	end

	local size = tonumber(data:gsub(";.*", ""), 16)
	if not size then
		return nil, "invalid chunk size"
	end
	self.chunk_size = size

	self.state = size > 0 and "data" or "trailer"

	return true
end

---@private
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ChunkedEncoding:receive_data(_size)
	local size = math.min(_size, self.chunk_size)
	local data, err, partial = self.soc:receive(size)
	data = data or partial

	if #data == 0 then
		return nil, err, ""
	end

	if #data == self.chunk_size then
		local line, _err, _ = self.soc:receive("*l")
		if not line then
			return nil, _err, ""
		end
		self.state = "size"
	end

	self.chunk_size = self.chunk_size - #data

	return data
end

---@param size integer
---@return string?
---@return "closed"|"timeout"|"invalid chunk size"|"malformed headers"?
---@return string?
function ChunkedEncoding:receive(size)
	if self.state == "size" then
		local ok, err = self:receive_size()
		if not ok then
			return nil, err, ""
		end
	end
	if self.state == "data" then
		return self:receive_data(size)
	end
	if self.state == "trailer" then
		local ok, err = self.headers:receive()
		if not ok then
			return nil, err, ""
		end
		return ""
	end
end

---@param chunk string?
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function ChunkedEncoding:send(chunk, i, j)
	assert(not i and not j, "not implemented")
	if chunk then
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
	local ok, err = self.headers:send()
	if not ok then
		return nil, err, 0
	end
	return 0
end

return ChunkedEncoding
