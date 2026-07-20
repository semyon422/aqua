local ITcpSocket = require("web.socket.ITcpSocket")

---@class web.Socks5ProxyOptions
---@field host string
---@field port integer
---@field username string?
---@field password string?

---@class web.Socks5TcpSocket: web.ITcpSocket
---@operator call: web.Socks5TcpSocket
---@field tcp_socket web.ITcpSocket
---@field proxy web.Socks5ProxyOptions
local Socks5TcpSocket = ITcpSocket + {}

local reply_errors = {
	[1] = "general SOCKS server failure",
	[2] = "SOCKS connection not allowed",
	[3] = "SOCKS network unreachable",
	[4] = "SOCKS host unreachable",
	[5] = "SOCKS connection refused",
	[6] = "SOCKS TTL expired",
	[7] = "SOCKS command not supported",
	[8] = "SOCKS address type not supported",
}

---@param tcp_socket web.ITcpSocket
---@param proxy web.Socks5ProxyOptions
function Socks5TcpSocket:new(tcp_socket, proxy)
	self.tcp_socket = tcp_socket
	self.proxy = proxy
	self.ssl_params = tcp_socket.ssl_params
end

---@param data string
---@return true?
---@return string?
function Socks5TcpSocket:sendAll(data)
	local index = 1
	while index <= #data do
		local last_byte, err, partial = self.tcp_socket:send(data, index)
		if not last_byte then
			if partial and partial >= index then
				index = partial + 1
			else
				return nil, err
			end
		else
			index = last_byte + 1
		end
	end
	return true
end

---@param size integer
---@return string?
---@return string?
function Socks5TcpSocket:receiveExact(size)
	local parts = {}
	local received = 0
	while received < size do
		local data, err, partial = self.tcp_socket:receive(size - received)
		data = data or partial
		if data and #data > 0 then
			table.insert(parts, data)
			received = received + #data
		end
		if not data or #data == 0 then
			return nil, err
		end
	end
	return table.concat(parts)
end

---@param host string
---@return string
local function encode_address(host)
	local octets = {host:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")}
	if #octets == 4 then
		for i, octet in ipairs(octets) do
			octets[i] = assert(tonumber(octet))
			assert(octets[i] <= 255, "invalid IPv4 address")
		end
		return string.char(1, octets[1], octets[2], octets[3], octets[4])
	end
	if host:find(":", 1, true) then
		local _, double_colon_count = host:gsub("::", "")
		assert(double_colon_count <= 1, "invalid IPv6 address")
		local left, right = host:match("^(.-)::(.-)$")
		local groups = {}
		local function append_groups(part)
			if part == "" then
				return
			end
			for group in part:gmatch("[^:]+") do
				local value = tonumber(group, 16)
				assert(value and #group <= 4 and value <= 0xFFFF, "invalid IPv6 address")
				table.insert(groups, value)
			end
		end

		if left ~= nil then
			append_groups(left)
			local right_groups = {}
			local original_groups = groups
			groups = right_groups
			append_groups(right)
			groups = original_groups
			local zero_count = 8 - #groups - #right_groups
			assert(zero_count >= 1, "invalid IPv6 address")
			for _ = 1, zero_count do
				table.insert(groups, 0)
			end
			for _, group in ipairs(right_groups) do
				table.insert(groups, group)
			end
		else
			append_groups(host)
			assert(#groups == 8, "invalid IPv6 address")
		end

		local bytes = {4}
		for _, group in ipairs(groups) do
			table.insert(bytes, math.floor(group / 256))
			table.insert(bytes, group % 256)
		end
		return string.char(unpack(bytes))
	end

	assert(#host <= 255, "SOCKS5 destination hostname is too long")
	return string.char(3, #host) .. host
end

---@return true?
---@return string?
function Socks5TcpSocket:authenticate()
	local username = self.proxy.username
	local password = self.proxy.password
	local methods = username and username ~= "" and "\0\2" or "\0"
	local ok, err = self:sendAll(string.char(5, #methods) .. methods)
	if not ok then
		return nil, err
	end

	local response
	response, err = self:receiveExact(2)
	if not response then
		return nil, err
	end
	if response:byte(1) ~= 5 then
		return nil, "invalid SOCKS5 greeting response"
	end

	local method = response:byte(2)
	if method == 0 then
		return true
	elseif method == 255 then
		return nil, "SOCKS5 proxy rejected authentication methods"
	elseif method ~= 2 or not username or username == "" then
		return nil, "SOCKS5 proxy selected an unsupported authentication method"
	end

	password = password or ""
	if #username > 255 or #password > 255 then
		return nil, "SOCKS5 username and password must be at most 255 bytes"
	end
	ok, err = self:sendAll(string.char(1, #username) .. username .. string.char(#password) .. password)
	if not ok then
		return nil, err
	end
	response, err = self:receiveExact(2)
	if not response then
		return nil, err
	end
	if response:byte(1) ~= 1 or response:byte(2) ~= 0 then
		return nil, "SOCKS5 username/password authentication failed"
	end
	return true
end

---@param host string
---@param port integer
---@return 1?
---@return string?
function Socks5TcpSocket:connect(host, port)
	local ok, err = self.tcp_socket:connect(self.proxy.host, self.proxy.port)
	if not ok then
		return nil, err
	end

	ok, err = self:authenticate()
	if not ok then
		return nil, err
	end

	local request = string.char(5, 1, 0) .. encode_address(host) .. string.char(math.floor(port / 256), port % 256)
	ok, err = self:sendAll(request)
	if not ok then
		return nil, err
	end

	local response
	response, err = self:receiveExact(4)
	if not response then
		return nil, err
	end
	if response:byte(1) ~= 5 then
		return nil, "invalid SOCKS5 connect response"
	end
	local reply = response:byte(2)
	if reply ~= 0 then
		return nil, reply_errors[reply] or ("unknown SOCKS5 error " .. reply)
	end

	local address_type = response:byte(4)
	local address_size
	if address_type == 1 then
		address_size = 4
	elseif address_type == 4 then
		address_size = 16
	elseif address_type == 3 then
		local length
		length, err = self:receiveExact(1)
		if not length then
			return nil, err
		end
		address_size = length:byte()
	else
		return nil, "invalid SOCKS5 bound address type"
	end

	local ignored
	ignored, err = self:receiveExact(address_size + 2)
	if not ignored then
		return nil, err
	end
	return 1
end

---@param name string
function Socks5TcpSocket:sni(name)
	return self.tcp_socket:sni(name)
end

---@return 1?
---@return string?
function Socks5TcpSocket:sslwrap()
	self.tcp_socket.ssl_params = self.ssl_params
	return self.tcp_socket:sslwrap()
end

---@return 1?
---@return string?
function Socks5TcpSocket:sslhandshake()
	return self.tcp_socket:sslhandshake()
end

---@param value number?
function Socks5TcpSocket:settimeout(value)
	return self.tcp_socket:settimeout(value)
end

---@return string
---@return integer
function Socks5TcpSocket:getpeername()
	return self.tcp_socket:getpeername()
end

---@param timeout integer?
---@return boolean
function Socks5TcpSocket:selectreceive(timeout)
	return self.tcp_socket:selectreceive(timeout)
end

---@param timeout integer?
---@return boolean
function Socks5TcpSocket:selectsend(timeout)
	return self.tcp_socket:selectsend(timeout)
end

---@param size integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function Socks5TcpSocket:receive(size)
	return self.tcp_socket:receive(size)
end

---@param max integer
---@return string?
---@return "closed"|"timeout"?
function Socks5TcpSocket:receiveany(max)
	return self.tcp_socket:receiveany(max)
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function Socks5TcpSocket:send(data, i, j)
	return self.tcp_socket:send(data, i, j)
end

---@return 1
function Socks5TcpSocket:close()
	return self.tcp_socket:close()
end

return Socks5TcpSocket
