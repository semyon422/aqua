local ISocket = require("web.socket.ISocket")

---@class web.ITcpSocket: web.ISocket
---@operator call: web.ITcpSocket
local ITcpSocket = ISocket + {}

---@param host string
---@param port integer
---@return 1?
---@return string?
function ITcpSocket:connect(host, port)
	error("not implemented")
end

---@return 1?
---@return string?
function ITcpSocket:sslhandshake()
	error("not implemented")
end

---@param time integer
function ITcpSocket:settimeout(time)
	error("not implemented")
end

return ITcpSocket
