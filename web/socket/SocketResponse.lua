local codes = require("web.socket.codes")
local IResponse = require("web.IResponse")
local Headers = require("web.socket.Headers")
local StatusLine = require("web.socket.StatusLine")

---@class web.SocketResponse: web.IResponse
---@operator call: web.SocketResponse
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
function SocketResponse:receiveStatusLine()
	if self.status_line_received then return end
	self.status_line_received = true
	local statusLine, err = StatusLine():receive(self.soc)
	if not statusLine then
		return nil, err
	end

	local status = tonumber(statusLine.status)
	if not status then
		return nil, "unknown status", statusLine.status
	end

	self.status = status

	return true
end

function SocketResponse:sendStatusLine()
	if self.status_line_sent then return end
	self.status_line_sent = true
	return StatusLine(self.status):receive(self.soc)
end

function SocketResponse:receiveHeaders()
	if self.headers_received then return end
	self.headers_received = true
	self:receiveStatusLine()
	return self.headers:receive(self.soc)
end

function SocketResponse:sendHeaders()
	if self.headers_sent then return end
	self.headers_sent = true
	self:sendStatusLine()
	return self.headers:send(self.soc)
end

---@param size integer
function SocketResponse:receive(size)
	self:receiveStatusLine()
	self:receiveHeaders()
	return self.soc:receive(size)
end

function SocketResponse:send(data)
	self:sendStatusLine()
	self:sendHeaders()
	if not data or data == "" then return end
	return self.soc:send(data)
end

return SocketResponse
