local IRequest = require("web.IRequest")
local Headers = require("web.socket.Headers")

---@class web.SocketRequest: web.IRequest
---@operator call: web.SocketRequest
---@field headers web.Headers
local SocketRequest = IRequest + {}

SocketRequest.method = "GET"
SocketRequest.uri = "/"
SocketRequest.protocol = "HTTP/1.1"

---@param soc web.AsyncSocket
function SocketRequest:new(soc)
	self.soc = soc
	self.headers = Headers()
end

---@return string?
---@return "closed"?
---@return string?
function SocketRequest:readStatusLine()
	local data, err, partial = self.soc:receive("*l")
	if not data then
		return nil, err, partial
	end

	self.method, self.uri, self.protocol = data:match("^(%S+)%s+(%S+)%s+(%S+)")

	return data, err, partial
end

function SocketRequest:writeStatusLine()
	local status_line = ("%s %s %s\r\n"):format(self.method, self.uri, self.protocol)
	return self.soc:send(status_line)
end

function SocketRequest:readHeaders()
	return self.headers:receive(self.soc)
end

function SocketRequest:writeHeaders()
	return self.headers:send(self.soc)
end

function SocketRequest:read(size)
	return self.soc:receive(size)
end

---@param data string
function SocketRequest:write(data)
	return self.soc:send(data)
end

return SocketRequest
