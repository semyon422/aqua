---@class web.LuaSocketTcp
---@field connect fun(self: web.LuaSocketTcp, host: string, port: integer): 1?, string?
---@field sni fun(self: web.LuaSocketTcp, name: string)
---@field dohandshake fun(self: web.LuaSocketTcp): 1?, string?
---@field settimeout fun(self: web.LuaSocketTcp, timeout: number?)
---@field getpeername fun(self: web.LuaSocketTcp): string, integer, "inet"|"inet6"
---@field receive fun(self: web.LuaSocketTcp, pattern: integer|string, prefix: string?): string?, string?, string?
---@field send fun(self: web.LuaSocketTcp, data: string, start: integer?, finish: integer?): integer?, string?, integer?
---@field close fun(self: web.LuaSocketTcp): 1

---@class web.LuaSocketModule
---@field tcp fun(): web.LuaSocketTcp
---@field tcp4 (fun(): web.LuaSocketTcp)?
---@field tcp6 (fun(): web.LuaSocketTcp)?
---@field select fun(read: web.LuaSocketTcp[]?, write: web.LuaSocketTcp[]?, timeout: number?): {[web.LuaSocketTcp]: any}, {[web.LuaSocketTcp]: any}, string?

---@type web.LuaSocketModule
local socket = require("socket")
local ITcpSocket = require("web.socket.ITcpSocket")

---@class web.TcpSocket: web.ITcpSocket
---@operator call: web.TcpSocket
---@field soc web.LuaSocketTcp
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
		self.soc = socket.tcp4 and socket.tcp4() or socket.tcp()
	elseif ver == 6 then
		self.soc = socket.tcp6 and socket.tcp6() or socket.tcp()
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

---@param name string
function LsTcpSocket:sni(name)
	self.soc:sni(name)
end

---@return 1?
---@return string?
function LsTcpSocket:sslwrap()
	---@type {wrap: fun(socket: web.LuaSocketTcp, parameters: table): web.LuaSocketTcp?, string?}
	local ssl = require("ssl")
	local soc, err = ssl.wrap(self.soc, self.ssl_params)
	if not soc then
		return nil, err
	end
	self.soc = soc
	return 1
end

---@return 1?
---@return string?
function LsTcpSocket:sslhandshake()
	local ok, err = self.soc:dohandshake()
	if not ok then
		return nil, err
	end
	return 1
end

---@param value integer?
function LsTcpSocket:settimeout(value)
	return self.soc:settimeout(value)
end

---@return string
---@return integer
function LsTcpSocket:getpeername()
	local ip, port = self.soc:getpeername()
	return ip, port
end

---@param timeout integer?
---@return boolean
function LsTcpSocket:selectreceive(timeout)
	local recvt = socket.select({self.soc}, nil, timeout)
	return not not recvt[self.soc]
end

---@param timeout integer?
---@return boolean
function LsTcpSocket:selectsend(timeout)
	local _, sendt = socket.select(nil, {self.soc}, timeout)
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

---@return 1
function LsTcpSocket:close()
	return self.soc:close()
end

return LsTcpSocket
