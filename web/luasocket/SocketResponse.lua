local IResponse = require("web.IResponse")
local Headers = require("web.http.Headers")
local StatusLine = require("web.http.StatusLine")
local RequestResponse = require("web.luasocket.RequestResponse")

---@class web.SocketResponse: web.IResponse, web.RequestResponse
---@operator call: web.SocketResponse
local SocketResponse = IResponse + RequestResponse

SocketResponse.status = 200

---@param soc web.IExtendedSocket
function SocketResponse:new(soc)
	self.soc = soc
	self.headers = Headers()
end

---@private
---@return true?
---@return "closed"|"timeout"|"unknown status"|"malformed headers"?
function SocketResponse:receiveInfo()
	if self.info_received then
		return true
	end
	self.info_received = true

	local sline, err = StatusLine():receive(self.soc)
	if not sline then
		return nil, err
	end

	local status = tonumber(sline.status)
	if not status then
		return nil, "unknown status"
	end
	self.status = status

	local headers, err = self.headers:receive(self.soc)
	if not headers then
		return nil, err
	end

	self:processHeaders()

	return true
end

---@private
---@return true?
---@return "closed"|"timeout"?
function SocketResponse:sendInfo()
	if self.info_sent then
		return true
	end
	self.info_sent = true

	local sline, err = StatusLine(self.status):send(self.soc)
	if not sline then
		return nil, err
	end

	local headers, err = self.headers:send(self.soc)
	if not headers then
		return nil, err
	end

	self:processHeaders()

	return true
end

return SocketResponse
