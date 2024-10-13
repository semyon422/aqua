local codes = require("web.socket.codes")
local IResponse = require("web.IResponse")
local Headers = require("web.socket.Headers")

---@class web.SocketResponse: web.IResponse
---@operator call: web.SocketResponse
---@field headers web.Headers
local SocketResponse = IResponse + {}

SocketResponse.protocol = "HTTP/1.1"
SocketResponse.status = 200

---@param soc web.AsyncSocket
function SocketResponse:new(soc)
	self.soc = soc
	self.headers = Headers()
end

---@return true?
---@return "closed"|"unknown status"?
---@return string?
function SocketResponse:readStatusLine()
	local data, err, partial = self.soc:receive("*l")
	if not data then
		return nil, err, partial
	end

	local protocol, status_s = data:match("(%S+)%s+(%S+)")
	local status = tonumber(status_s)
	if not status then
		return nil, "unknown status", data
	end

	self.protocol = protocol
	self.status = status

	return true
end

function SocketResponse:writeStatusLine()
	local status_line = ("%s %s %s\r\n"):format(self.protocol, self.status, codes[self.status])
	return self.soc:send(status_line)
end

function SocketResponse:readHeaders()
	return self.headers:receive(self.soc)
end

function SocketResponse:writeHeaders()
	return self.headers:send(self.soc)
end

function SocketResponse:write(data)
	return self.soc:send(data)
end

---@param size integer
function SocketResponse:read(size)
	return self.soc:receive(size)
end

return SocketResponse
