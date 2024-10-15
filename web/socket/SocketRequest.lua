local IRequest = require("web.IRequest")
local Headers = require("web.socket.Headers")
local RequestLine = require("web.socket.RequestLine")

---@class web.SocketRequest: web.IRequest
---@operator call: web.SocketRequest
local SocketRequest = IRequest + {}

---@param soc web.AsyncSocket
function SocketRequest:new(soc)
	self.soc = soc
	self.headers = Headers()
end

function SocketRequest:receiveRequestLine()
	if self.request_line_received then return end
	self.request_line_received = true
	local requestLine, err = RequestLine():receive(self.soc)
	if not requestLine then
		return nil, err
	end
	self.method = requestLine.method
	self.uri = requestLine.uri
end

function SocketRequest:sendRequestLine()
	if self.request_line_sent then
		return
	end
	self.request_line_sent = true
	return RequestLine(self.method, self.uri):send(self.soc)
end

function SocketRequest:receiveHeaders()
	if self.headers_received then return end
	self.headers_received = true
	self:receiveRequestLine()
	return self.headers:receive(self.soc)
end

function SocketRequest:sendHeaders()
	if self.headers_sent then return end
	self.headers_sent = true
	self:sendRequestLine()
	return self.headers:send(self.soc)
end

function SocketRequest:receive(size)
	self:receiveRequestLine()
	self:receiveHeaders()
	return self.soc:receive(size)
end

---@param data string
function SocketRequest:send(data)
	self:sendRequestLine()
	self:sendHeaders()
	if not data or data == "" then return end
	return self.soc:send(data)
end

return SocketRequest
