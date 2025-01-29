local IRequest = require("web.http.IRequest")
local RequestLine = require("web.http.RequestLine")
local RequestResponse = require("web.http.RequestResponse")

---@class web.Request: web.IRequest, web.RequestResponse
---@operator call: web.Request
local Request = IRequest + RequestResponse

---@type web.HttpMethod
Request.method = "GET"
Request.uri = "/"

---@return 1?
---@return "closed"|"timeout"|"malformed headers"?
function Request:receive_headers()
	self:assert_mode("r")

	if self.headers_received then
		return 1
	end
	self.headers_received = true

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

	self:process_headers()

	return 1
end

---@return 1?
---@return "closed"|"timeout"?
function Request:send_headers()
	self:assert_mode("w")

	if self.headers_sent then
		return 1
	end
	self.headers_sent = true

	local rline, err = RequestLine(self.method, self.uri):send(self.soc)
	if not rline then
		return nil, err
	end

	local headers, err = self.headers:send(self.soc)
	if not headers then
		return nil, err
	end

	self:process_headers()

	return 1
end

return Request
