local socket = require("socket")
local ISocket = require("web.socket.ISocket")

---@class web.TcpSocket: web.ISocket
---@operator call: web.TcpSocket
local TcpSocket = ISocket + {}

---@param address string
---@param port integer
---@return 1?
---@return string?
function TcpSocket:connect(address, port)
	local soc = socket.tcp()

	local ok, err = soc:connect(address, port)
	if not ok then
		return nil, err
	end

	self.soc = soc

	return 1
end

---@param value integer?
function TcpSocket:settimeout(value)
	return self.soc:settimeout(value)
end

---@param size integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function TcpSocket:receive(size)
	return self.soc:receive(size)
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function TcpSocket:send(data, i, j)
	return self.soc:send(data, i, j)
end

return TcpSocket
