local ITransferEncoding = require("web.http.ITransferEncoding")
local Headers = require("web.http.Headers")

-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Transfer-Encoding
-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Trailer

---@class web.ChunkedEncoding: web.ITransferEncoding
---@operator call: web.ChunkedEncoding
local ChunkedEncoding = ITransferEncoding + {}

ChunkedEncoding.name = "chunked"

---@param soc web.IExtendedSocket
function ChunkedEncoding:new(soc)
	self.soc = soc
	self.headers = Headers()
	self.remainder = ""

	---@type "size"|"data"|"trailer"
	self.state = "size"
end

---@private
---@return string?
---@return "closed"|"timeout"|"invalid chunk size"?
---@return string?
function ChunkedEncoding:receive_size()
	local rem = self.remainder

	local data, err, partial = self.soc:receive("*l", rem)
	if not data then
		self.remainder = partial
		return nil, err, ""
	end

	local size = tonumber(data:gsub(";.*", ""), 16)
	if not size then
		return nil, "invalid chunk size"
	end
	self.chunk_size = size
	self.remainder = ""

	self.state = size > 0 and "data" or "trailer"

	return ""
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
		self.soc:receive("*l")
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
		local data, err, partial = self:receive_size()
		if not data then
			return nil, err, partial
		end
	end
	if self.state == "data" then
		return self:receive_data(size)
	end
	if self.state == "trailer" then
		local data, err, partial = self.headers:receive(self.soc)
		if not data then
			return nil, err, partial
		end
	end
end

---@param chunk string?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function ChunkedEncoding:send(chunk)
	if chunk then
		return self.soc:send(("%X\r\n%s\r\n"):format(#chunk, chunk))
	end
	local last_byte, err, _last_byte = self.soc:send("0\r\n")
	if not last_byte then
		return nil, err, _last_byte
	end
	return self.headers:send(self.soc)
end

return ChunkedEncoding
