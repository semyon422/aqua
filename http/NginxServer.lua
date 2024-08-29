local class = require("class")

---@class http.NginxServer
---@operator call: http.NginxServer
local NginxServer = class()

function NginxServer:handle()
	local req = {}

	req.headers = ngx.req.get_headers()
	req.method = ngx.req.get_method()
	req.uri = ngx.var.request_uri

	ngx.status = 200
	ngx.header["Test-Header"] = "hello"
	ngx.print("Hello world")
end

return NginxServer
