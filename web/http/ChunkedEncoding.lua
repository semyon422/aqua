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
end

---@return string?
---@return "closed"|"timeout"|"invalid chunk size"|"malformed headers"?
---@return string?
function ChunkedEncoding:receive()
	local data, err, partial = self.soc:receive("*l")
	if not data then
		return nil, err, partial
	end

	local size = tonumber(data:gsub(";.*", ""), 16)
	if not size then
		return nil, "invalid chunk size"
	end

	if size > 0 then
		data, err, partial = self.soc:receive(size)
		if data then
			self.soc:receive("*l")
		end
		return data, err, partial
	end

	data, err, partial = self.headers:receive(self.soc)
	if not data then
		return nil, err, partial
	end
end

---@param chunk string
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function ChunkedEncoding:send(chunk)
	return self.soc:send(("%X\r\n%s\r\n"):format(#chunk, chunk))
end

---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function ChunkedEncoding:close()
	local last_byte, err, _last_byte = self.soc:send("0\r\n")
	if not last_byte then
		return nil, err, _last_byte
	end
	return self.headers:send(self.soc)
end

return ChunkedEncoding
