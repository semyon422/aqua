local IResponse = require("web.IResponse")
local Headers = require("web.http.Headers")
local StatusLine = require("web.http.StatusLine")

---@class web.SocketResponse: web.IResponse
---@operator call: web.SocketResponse
local SocketResponse = IResponse + {}

SocketResponse.status = 200

---@param soc web.IExtendedSocket
function SocketResponse:new(soc)
	self.soc = soc
	self.headers = Headers()
end

function SocketResponse:receiveInfo()
	if self.info_received then
		return
	end
	self.info_received = true

	local sline, err = StatusLine():receive(self.soc)
	if not sline then
		return nil, err
	end

	local status = tonumber(sline.status)
	if not status then
		return nil, "unknown status", sline.status
	end

	self.status = status
	self.headers:receive(self.soc)
end

function SocketResponse:sendInfo()
	if self.info_sent then return end
	self.info_sent = true
	StatusLine(self.status):send(self.soc)
	self.headers:send(self.soc)
end

---@param pattern "*a"|"*l"|integer?
function SocketResponse:receive(pattern)
	self:receiveInfo()
	if not pattern or pattern == 0 then return end
	return self.soc:receive(pattern)
end

---@param data string?
function SocketResponse:send(data)
	self:sendInfo()
	if not data or data == "" then return end
	return self.soc:send(data)
end

return SocketResponse
