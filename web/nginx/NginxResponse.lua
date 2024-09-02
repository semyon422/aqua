local IResponse = require("web.IResponse")

---@class web.NginxResponse: web.IResponse
---@operator call: web.NginxResponse
local NginxResponse = IResponse + {}

function NginxResponse:new()
	self.status = 200
	---@type {[string]: string}
	self.headers = {}
	self.headers_set = false
end

function NginxResponse:setHeaders()
	ngx.status = self.status
	for k, v in pairs(self.headers) do
		ngx.header[k] = v
	end
	self.headers_set = true
end

---@param body string?
function NginxResponse:write(body)
	if not self.headers_set then
		self:setHeaders()
	end
	if not body then
		return
	end
	ngx.print(body)
end

return NginxResponse
