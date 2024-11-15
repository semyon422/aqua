local class = require("class")

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
---@return web.RequestLine?
---@return "closed"|"timeout"?
---@return string?
function RequestLine:receive(soc)
	local data, err, partial = soc:receive("*l")
	if not data then
		return nil, err, partial
	end

	self.method, self.uri, self.version = data:match("^(%S+)%s+(%S+)%s+(%S+)")

	return self
end

---@param soc web.IExtendedSocket
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function RequestLine:send(soc)
	local status_line = ("%s %s %s\r\n"):format(self.method, self.uri, self.version)
	return soc:send(status_line)
end

return RequestLine
