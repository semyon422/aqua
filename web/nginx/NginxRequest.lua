local IRequest = require("web.IRequest")

---@class web.NginxRequest: web.IRequest
---@operator call: web.NginxRequest
local NginxRequest = IRequest + {}

function NginxRequest:new()
	self.headers = ngx.req.get_headers()
	self.method = ngx.req.get_method()
	self.uri = ngx.var.request_uri
end

return NginxRequest
