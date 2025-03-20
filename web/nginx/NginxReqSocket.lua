local NginxTcpSocket = require("web.nginx.NginxTcpSocket")

---@class web.NginxReqSocket: web.NginxTcpSocket
---@operator call: web.NginxReqSocket
local NginxReqSocket = NginxTcpSocket + {}

function NginxReqSocket:new()
	self.soc = assert(ngx.req.socket(true))
end

---@return string
---@return integer
function NginxReqSocket:getpeername()
	return ngx.var.remote_addr, tonumber(ngx.var.remote_port) or 0
end

return NginxReqSocket
