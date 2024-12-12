local NginxTcpSocket = require("web.nginx.NginxTcpSocket")

---@class web.NginxReqSocket: web.NginxTcpSocket
---@operator call: web.NginxReqSocket
local NginxReqSocket = NginxTcpSocket + {}

function NginxReqSocket:new()
	self.soc = assert(ngx.req.socket(true))
end

return NginxReqSocket
