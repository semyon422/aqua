local IRequest = require("web.IRequest")
local Headers = require("web.http.Headers")
local RequestLine = require("web.http.RequestLine")

---@class web.SocketRequest: web.IRequest
---@operator call: web.SocketRequest
local SocketRequest = IRequest + {}

---@param soc web.IExtendedSocket
function SocketRequest:new(soc)
	self.soc = soc
	self.headers = Headers()
end

---@return true?
---@return "closed"|"timeout"|"malformed headers"?
function SocketRequest:receiveInfo()
	if self.info_received then
		return true
	end
	self.info_received = true

	local rline, err = RequestLine():receive(self.soc)
	if not rline then
		return nil, err
	end

	self.method = rline.method
	self.uri = rline.uri

	local headers, err = self.headers:receive(self.soc)
	if not headers then
		return nil, err
	end

	return true
end

function SocketRequest:sendInfo()
	if self.info_sent then
		return true
	end
	self.info_sent = true

	local rline, err = RequestLine(self.method, self.uri):send(self.soc)
	if not rline then
		return nil, err
	end

	local headers, err = self.headers:send(self.soc)
	if not headers then
		return nil, err
	end

	return true
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"|"malformed headers"?
---@return string?
function SocketRequest:receive(pattern, prefix)
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
function SocketRequest:send(data, i, j)
	local ok, err = self:sendInfo()
	if not ok then
		return nil, err, (i or 1) - 1
	end
	return self.soc:send(data, i, j)
end

return SocketRequest
