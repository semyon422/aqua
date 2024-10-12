local IRequest = require("web.IRequest")
local Headers = require("web.socket.Headers")

---@class web.SocketRequest: web.IRequest
---@operator call: web.SocketRequest
local SocketRequest = IRequest + {}

SocketRequest.protocol = "HTTP/1.1"

---@param soc web.AsyncSocket
function SocketRequest:new(soc)
	self.soc = soc
	---@type {[string]: string}
	self.headers = {}
end

---@return true?
---@return "closed"?
function SocketRequest:readStatusLine()
	local line, err = self.soc:receive("*l")
	if not line then
		return nil, err
	end

	self.method, self.uri, self.protocol = line:match("^(%S+)%s+(%S+)%s+(%S+)")

	return true
end

---@return true?
---@return "closed"?
function SocketRequest:writeStatusLine()
	local status_line = ("%s %s %s\r\n"):format(self.method, self.uri, self.protocol)

	local ok, err = self.soc:send(status_line)
	if not ok then
		return nil, err
	end

	return true
end

---@return true?
---@return string?
function SocketRequest:readHeaders()
	local headers_obj = Headers()

	local ok, err = headers_obj:decode(function()
		return self.soc:receive("*l")
	end)
	if not ok then
		return nil, err
	end

	self.headers = headers_obj.headers
	self.length = tonumber(self.headers["Content-Length"]) or 0

	return true
end

---@return true?
---@return "closed"?
function SocketRequest:writeHeaders()
	local headers_obj = Headers()
	headers_obj.headers = self.headers

	local ok, err = self.soc:send(headers_obj:encode())
	if not ok then
		return nil, err
	end

	return true
end

---@param size integer
---@return string
function SocketRequest:read(size)
	local length = tonumber(self.headers["Content-Length"]) or 0
	if length == 0 then
		return ""
	end
	return assert(self.soc:receive(size))
end

---@param data string
function SocketRequest:write(data)
	assert(self.soc:send(data))
end

return SocketRequest
