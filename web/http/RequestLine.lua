local class = require("class")
local receive_line = require("web.http.receive_line")

-- https://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html

---@class web.RequestLine
---@operator call: web.RequestLine
---@field method string
---@field uri string
---@field version string
local RequestLine = class()

RequestLine.method = "GET"
RequestLine.uri = "/"
RequestLine.version = "HTTP/1.1"

---@param method string
---@param uri string
function RequestLine:new(method, uri)
	self.method = method
	self.uri = uri
end

---@param soc web.IExtendedSocket
---@param max_size integer?
---@return web.RequestLine?
---@return "closed"|"timeout"|"line too long"|"malformed request line"?
function RequestLine:receive(soc, max_size)
	local data, err = receive_line(soc, max_size)
	if not data then
		return nil, err
	end
	self.method, self.uri, self.version = data:match("^(%S+)%s+(%S+)%s+(%S+)$")
	if not self.method then
		return nil, "malformed request line"
	end
	return self
end

---@param soc web.IExtendedSocket
---@return web.RequestLine?
---@return "closed"|"timeout"?
function RequestLine:send(soc)
	local status_line = ("%s %s %s\r\n"):format(self.method, self.uri, self.version)
	local bytes_sent, err = soc:send(status_line)
	if not bytes_sent then
		return nil, err
	end
	return self
end

return RequestLine
