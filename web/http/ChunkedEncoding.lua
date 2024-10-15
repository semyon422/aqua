local class = require("class")

-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Transfer-Encoding
-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Trailer

---@class web.ChunkedEncoding
---@operator call: web.ChunkedEncoding
local ChunkedEncoding = class()

---@param soc web.IAsyncSocket
function ChunkedEncoding:new(soc)
	self.soc = soc
end

---@param headers web.Headers?
---@return string?
---@return "closed"|"invalid chunk size"|"malformed headers"?
---@return string?
function ChunkedEncoding:receive(headers)
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

	if not headers then
		return
	end

	data, err, partial = headers:receive(self.soc)
	if not data then
		return nil, err, partial
	end
end

---@param chunk string?
---@return integer?
---@return "closed"?
---@return integer?
function ChunkedEncoding:send(chunk)
	return self.soc:send(("%X\r\n%s\r\n"):format(#chunk, chunk))
end

---@param headers web.Headers?
---@return integer?
---@return "closed"?
---@return integer?
function ChunkedEncoding:close(headers)
	if not headers then
		return self.soc:send("0\r\n\r\n")
	end
	local last_byte, err, _last_byte = self.soc:send("0\r\n")
	if not last_byte then
		return nil, err, _last_byte
	end
	return headers:send(self.soc)
end

return ChunkedEncoding
