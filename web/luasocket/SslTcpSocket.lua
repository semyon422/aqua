local socket = require("socket")
local ISocket = require("web.socket.ISocket")

---@class web.SslTcpSocket: web.ISocket
---@operator call: web.SslTcpSocket
local SslTcpSocket = ISocket + {}

SslTcpSocket.ssl_params = {
	mode = "client",
	protocol = "any",
	options = {"all", "no_sslv2", "no_sslv3", "no_tlsv1"},
	verify = "none",
}

---@param address string
---@param port integer
---@return 1?
---@return string?
function SslTcpSocket:connect(address, port)
	local soc = socket.tcp()

	local ok, err = soc:connect(address, port)
	if not ok then
		return nil, err
	end

	local ssl = require("ssl")
	soc = ssl.wrap(soc, self.ssl_params)
	soc:dohandshake()

	self.soc = soc

	return 1
end

---@param value integer?
function SslTcpSocket:settimeout(value)
	return self.soc:settimeout(value)
end

---@param size integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function SslTcpSocket:receive(size)
	local data, err, partial = self.soc:receive(size)
	if err == "wantread" then
		err = "timeout"
	end
	return data, err, partial
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function SslTcpSocket:send(data, i, j)
	return self.soc:send(data, i, j)
end

return SslTcpSocket
