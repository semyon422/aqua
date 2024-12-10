local IRequest = require("web.http.IRequest")
local Headers = require("web.http.Headers")
local RequestLine = require("web.http.RequestLine")
local RequestResponse = require("web.http.RequestResponse")

---@class web.Request: web.IRequest, web.RequestResponse
---@operator call: web.Request
local Request = IRequest + RequestResponse

---@param soc web.IExtendedSocket
function Request:new(soc)
	self.soc = soc
	self.headers = Headers()
end

---@private
---@return true?
---@return "closed"|"timeout"|"malformed headers"?
function Request:receiveInfo()
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

	self:processHeaders()

	return true
end

---@private
---@return true?
---@return "closed"|"timeout"?
function Request:sendInfo()
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

	self:processHeaders()

	return true
end

return Request
