local IResponse = require("web.IResponse")
local Headers = require("web.http.Headers")
local StatusLine = require("web.http.StatusLine")
local LengthSocket = require("web.socket.LengthSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")

---@class web.SocketResponse: web.IResponse
---@operator call: web.SocketResponse
local SocketResponse = IResponse + {}

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

	local length = tonumber(headers:get("Content-Length"))
	if length then
		self.soc = ExtendedSocket(LengthSocket(self.soc, length))
	end

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

	local length = tonumber(headers:get("Content-Length"))
	if length then
		self.soc = ExtendedSocket(LengthSocket(self.soc, length))
	end

	return true
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"|"unknown status"|"malformed headers"?
---@return string?
function SocketResponse:receive(pattern, prefix)
	local ok, err = self:receiveInfo()
	if not ok then
		return nil, err, ""
	end
	return self.soc:receive(pattern, prefix)
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function SocketResponse:send(data, i, j)
	local ok, err = self:sendInfo()
	if not ok then
		return nil, err, (i or 1) - 1
	end
	return self.soc:send(data, i, j)
end

return SocketResponse
