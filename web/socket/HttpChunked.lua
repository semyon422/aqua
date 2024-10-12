local class = require("class")

-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Trailer

---@class web.HttpChunked
---@operator call: web.HttpChunked
local HttpChunked = class()

---@param soc web.ISocket
function HttpChunked:new(soc)
	self.soc = soc
end

---@param headers web.Headers
---@return string?
---@return string?
function HttpChunked:decode(headers)
	local line, err = self.soc:receive("*l")
	if not line then
		return nil, err
	end

	local size = tonumber(line:gsub(";.*", ""), 16)
	if not size then
		return nil, "invalid chunk size"
	end

	if size > 0 then
		local chunk, err, partial = self.soc:receive(size)
		if chunk then
			self.soc:receive("*l")
		end
		return chunk, err, partial
	end

	local ok, err = headers:decode(function()
		return self.soc:receive("*l")
	end)
	if not ok then
		return nil, err
	end
end

---@param chunk string?
---@param headers web.Headers?
function HttpChunked:encode(chunk, headers)
	if not chunk then
		if not headers then
			return self.soc:send("0\r\n\r\n")
		end
		return self.soc:send("0\r\n" .. headers:encode())
	end
	return self.soc:send(("%X\r\n%s\r\n"):format(#chunk, chunk))
end

return HttpChunked
