local IRequest = require("web.IRequest")
local Headers = require("web.http.Headers")
local RequestLine = require("web.http.RequestLine")

---@class web.SocketRequest: web.IRequest
---@operator call: web.SocketRequest
local SocketRequest = IRequest + {}

---@param soc web.IExtendedSocket
function SocketRequest:new(soc)
	self.soc = soc
	self.headers = Headers(soc)
end

function SocketRequest:receiveInfo()
	if self.info_received then
		return
	end
	self.info_received = true

	local rline, err = RequestLine():receive(self.soc)
	if not rline then
		return nil, err
	end

	self.method = rline.method
	self.uri = rline.uri
	self.headers:receive()
end

function SocketRequest:sendInfo()
	if self.info_sent then return end
	self.info_sent = true
	RequestLine(self.method, self.uri):send(self.soc)
	self.headers:send()
end

---@param pattern "*a"|"*l"|integer?
function SocketRequest:receive(pattern)
	self:receiveInfo()
	if not pattern or pattern == 0 then return end
	return self.soc:receive(pattern)
end

---@param data string?
function SocketRequest:send(data)
	self:sendInfo()
	if not data or data == "" then return end
	return self.soc:send(data)
end

return SocketRequest
