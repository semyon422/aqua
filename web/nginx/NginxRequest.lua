local IRequest = require("web.http.IRequest")
local Headers = require("web.http.Headers")
local RequestResponse = require("web.http.RequestResponse")

---@class web.NginxRequest: web.IRequest
---@operator call: web.NginxRequest
local NginxRequest = IRequest + {}

---@param soc web.IExtendedSocket
function NginxRequest:new(soc)
	self.soc = soc
	self.headers = Headers()
end

---@return 1?
---@return "closed"|"timeout"|"malformed headers"?
function NginxRequest:receive_headers()
	if self.headers_received then
		return 1
	end
	self.headers_received = true

	---@type web.HttpMethod
	self.method = ngx.req.get_method()
	self.uri = ngx.var.request_uri

	local h, err = ngx.req.get_headers()

	for k, v in pairs(h) do
		self.headers:set(k, v)
	end

	RequestResponse.process_headers(self) ---@diagnostic disable-line

	return 1
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"|"malformed headers"?
---@return string?
function NginxRequest:receive(pattern, prefix)
	assert(not prefix)
	local ok, err = self:receive_headers()
	if not ok then
		return nil, err, ""
	end
	return self.soc:receive(pattern)
end

return NginxRequest
