local socket = require("socket")
local ITcpSocket = require("web.socket.ITcpSocket")

---@class web.TcpSocket: web.ITcpSocket
---@operator call: web.TcpSocket
local LsTcpSocket = ITcpSocket + {}

LsTcpSocket.ssl_params = {
	mode = "client",
	protocol = "any",
	options = {"all", "no_sslv2", "no_sslv3", "no_tlsv1"},
	verify = "none",
}

---@param ver 4|6?
function LsTcpSocket:new(ver)
	if ver == nil then
		self.soc = socket.tcp()
	elseif ver == 4 then
		self.soc = socket.tcp4()
	elseif ver == 6 then
		self.soc = socket.tcp6()
	else
		error("invalid IP version: " .. tostring(ver))
	end
end

---@param host string
---@param port integer
---@return 1?
---@return string?
function LsTcpSocket:connect(host, port)
	return self.soc:connect(host, port)
end

---@return 1?
---@return string?
function LsTcpSocket:sslhandshake()
	local ssl = require("ssl")
	local soc, err = ssl.wrap(self.soc, self.ssl_params)
	if not soc then
		return nil, err
	end
	local ok, err = soc:dohandshake()
	if not ok then
		return nil, err
	end
	self.soc = soc
	return 1
end

---@param value integer?
function LsTcpSocket:settimeout(value)
	return self.soc:settimeout(value)
end

---@return string
---@return integer
function LsTcpSocket:getpeername()
	---@type string, integer, "inet"|"inet6"
	local ip, port, family = self.soc:getpeername()
	return ip, port
end

---@param timeout integer?
---@return boolean
function LsTcpSocket:selectreceive(timeout)
	local recvt, _, err = socket.select({self.soc}, nil, timeout)
	---@cast recvt {[TCPSocket]: any}
	return not not recvt[self.soc]
end

---@param timeout integer?
---@return boolean
function LsTcpSocket:selectsend(timeout)
	local _, sendt, err = socket.select(nil, {self.soc}, timeout)
	---@cast sendt {[TCPSocket]: any}
	return not not sendt[self.soc]
end

---@param size integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function LsTcpSocket:receive(size)
	local data, err, partial = self.soc:receive(size)
	if err == "wantread" then -- SSL error
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
function LsTcpSocket:send(data, i, j)
	return self.soc:send(data, i, j)
end

return LsTcpSocket
