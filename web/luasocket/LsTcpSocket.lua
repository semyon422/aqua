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

---@param host string
---@param port integer
---@return 1?
---@return string?
function LsTcpSocket:connect(host, port)
	local soc = socket.tcp()

	local ok, err = soc:connect(host, port)
	if not ok then
		return nil, err
	end

	self.soc = soc

	return 1
end

function LsTcpSocket:sslhandshake()
	local ssl = require("ssl")
	self.soc = ssl.wrap(self.soc, self.ssl_params)
	self.soc:dohandshake()
end


---@param value integer?
function LsTcpSocket:settimeout(value)
	return self.soc:settimeout(value)
end

---@param size integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function LsTcpSocket:receive(size)
	local data, err, partial = self.soc:receive(size)
	if err == "wantread" then  -- SSL error
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
