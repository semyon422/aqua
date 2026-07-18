local IRequest = require("web.http.IRequest")
local RequestLine = require("web.http.RequestLine")
local RequestResponse = require("web.http.RequestResponse")

---@class web.HttpRequestLimits: web.HttpHeaderLimits
---@field max_request_line_size integer?

---@class web.Request: web.IRequest, web.RequestResponse
---@operator call: web.Request
local Request = IRequest + RequestResponse

---@type web.HttpMethod
Request.method = "GET"
Request.uri = "/"

---@param limits web.HttpRequestLimits?
---@return 1?
---@return "closed"|"timeout"|"malformed request line"|"malformed headers"|"line too long"|"headers too large"|"too many headers"?
function Request:receive_headers(limits)
	self:assert_mode("r")

	if self.headers_received then
		return 1
	end
	self.headers_received = true

	local rline, err = RequestLine():receive(self.soc, limits and limits.max_request_line_size)
	if not rline then
		return nil, err
	end

	self.method = rline.method
	self.uri = rline.uri

	local headers, err = self.headers:receive(self.soc, limits)
	if not headers then
		return nil, err
	end

	local ok, _err = self:process_headers()
	if not ok then
		return nil, _err
	end

	return 1
end

---@return 1?
---@return "closed"|"timeout"|"malformed headers"?
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

	local ok, _err = self:process_headers()
	if not ok then
		return nil, _err
	end

	return 1
end

return Request
