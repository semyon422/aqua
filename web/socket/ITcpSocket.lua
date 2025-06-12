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

---@param name string
function ITcpSocket:sni(name)
	error("not implemented")
end

---@return 1?
---@return string?
function ITcpSocket:sslwrap()
	return 1
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

---@return string
---@return integer
function ITcpSocket:getpeername()
	error("not implemented")
end

---@param timeout integer?
---@return boolean
function ITcpSocket:selectreceive(timeout)
	error("not implemented")
end

---@param timeout integer?
---@return boolean
function ITcpSocket:selectsend(timeout)
	error("not implemented")
end

return ITcpSocket
