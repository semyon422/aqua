local ITcpSocket = require("web.socket.ITcpSocket")

---@class web.NginxTcpSocket: web.ITcpSocket
---@operator call: web.NginxTcpSocket
local NginxTcpSocket = ITcpSocket + {}

---@param soc tcpsock?
function NginxTcpSocket:new(soc)
	self.soc = soc or assert(ngx.socket.tcp())
end

---@param host string
---@param port integer
---@return 1?
---@return string?
function NginxTcpSocket:connect(host, port)
	return self.soc:connect(host, port) ---@diagnostic disable-line
end

---@return 1?
---@return string?
function NginxTcpSocket:sslhandshake()
	return self.soc:sslhandshake() ---@diagnostic disable-line
end

---@param time integer
function NginxTcpSocket:settimeout(time)
	return self.soc:settimeout(time * 1000) ---@diagnostic disable-line
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function NginxTcpSocket:receive(pattern, prefix)
	return self.soc:receive(pattern)
end

---@param max integer
---@return string?
---@return "closed"|"timeout"?
function NginxTcpSocket:receiveany(max)
	return self.soc:receiveany(max)
end

---@param pattern string
---@param options {inclusive: boolean?}?
---@return fun(size: integer?): string?, "closed"|"timeout"?, string?
function NginxTcpSocket:receiveuntil(pattern, options)
	return self.soc:receiveuntil(pattern, options)
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function NginxTcpSocket:send(data, i, j)
	assert(not i and not j, "not implemented")
	return self.soc:send(data)
end

---@return 1
function NginxTcpSocket:close()
	return self.soc:close() ---@diagnostic disable-line
end

return NginxTcpSocket
