local class = require("class")

-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Transfer-Encoding
-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Trailer

---@class web.HttpChunked
---@operator call: web.HttpChunked
local HttpChunked = class()

---@param soc web.IAsyncSocket
function HttpChunked:new(soc)
	self.soc = soc
end

---@param headers web.Headers
---@return string?
---@return "closed"|"invalid chunk size"|"malformed headers"?
---@return string?
function HttpChunked:decode(headers)
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

	data, err, partial = headers:receive(self.soc)
	if not data then
		return nil, err, partial
	end
end

---@param chunk string?
---@param headers web.Headers?
function HttpChunked:encode(chunk, headers)
	if not chunk then
		if not headers then
			return self.soc:send("0\r\n\r\n")
		end
		self.soc:send("0\r\n")
		return headers:send(self.soc)
	end
	return self.soc:send(("%X\r\n%s\r\n"):format(#chunk, chunk))
end

return HttpChunked
