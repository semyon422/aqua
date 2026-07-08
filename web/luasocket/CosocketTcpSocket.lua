local socket = require("socket")

local ITcpSocket = require("web.socket.ITcpSocket")

---@class web.CosocketTcpSocket: web.ITcpSocket
---@operator call: web.CosocketTcpSocket
local CosocketTcpSocket = ITcpSocket + {}

CosocketTcpSocket.ssl_params = {
	mode = "client",
	protocol = "any",
	options = {"all", "no_sslv2", "no_sslv3", "no_tlsv1"},
	verify = "none",
}

---@param scheduler web.CosocketScheduler
---@param ver 4|6?
---@param soc any?
function CosocketTcpSocket:new(scheduler, ver, soc)
	self.scheduler = scheduler
	self.timeout = nil

	if soc then
		self.soc = soc
	elseif ver == nil then
		self.soc = socket.tcp()
	elseif ver == 4 then
		self.soc = socket.tcp4 and socket.tcp4() or socket.tcp()
	elseif ver == 6 then
		self.soc = socket.tcp6 and socket.tcp6() or socket.tcp()
	else
		error("invalid IP version: " .. tostring(ver))
	end

	self.soc:settimeout(0)
end

---@return number?
function CosocketTcpSocket:getDeadline()
	local timeout = self.timeout
	if not timeout then
		return
	end
	return self.scheduler.get_time() + timeout
end

---@param deadline number?
---@return number?
function CosocketTcpSocket:getRemainingTimeout(deadline)
	if not deadline then
		return
	end
	return math.max(deadline - self.scheduler.get_time(), 0)
end

---@param mode web.CosocketWaitMode
---@param deadline number?
---@return true?
---@return string?
function CosocketTcpSocket:wait(mode, deadline)
	local timeout = self:getRemainingTimeout(deadline)
	if timeout == 0 then
		return nil, "timeout"
	elseif mode == "read" then
		return self.scheduler:waitRead(self.soc, timeout)
	elseif mode == "write" then
		return self.scheduler:waitWrite(self.soc, timeout)
	end
	error("invalid wait mode: " .. tostring(mode))
end

---@param err string?
---@param default_mode web.CosocketWaitMode
---@return web.CosocketWaitMode?
local function get_wait_mode(err, default_mode)
	if err == "timeout" then
		return default_mode
	elseif err == "wantread" then
		-- LuaSec can need socket read readiness while progressing a TLS operation.
		return "read"
	elseif err == "wantwrite" then
		-- LuaSec can need socket write readiness while progressing a TLS operation.
		return "write"
	end
end

---@param host string
---@param port integer
---@return 1?
---@return string?
function CosocketTcpSocket:connect(host, port)
	local deadline = self:getDeadline()
	local tried_more_than_once = false

	while true do
		local ok, err = self.soc:connect(host, port)
		if ok then
			return 1
		elseif err == "already connected" and tried_more_than_once then
			-- Windows may report this after a nonblocking connect becomes write-ready.
			return 1
		elseif err ~= "timeout" and err ~= "Operation already in progress" then
			return nil, err
		end

		-- Nonblocking connect is completed by waiting for write readiness and retrying.
		tried_more_than_once = true
		ok, err = self:wait("write", deadline)
		if not ok then
			return nil, err
		end
	end
end

---@param name string
function CosocketTcpSocket:sni(name)
	self.server_name = name
	local soc = self.soc
	if soc.sni then
		soc:sni(name)
	end
end

---@return 1?
---@return string?
function CosocketTcpSocket:sslwrap()
	local ssl = require("ssl")
	local soc, err = ssl.wrap(self.soc, self.ssl_params)
	if not soc then
		return nil, err
	end
	self.soc = soc
	self.soc:settimeout(0)
	return 1
end

---@return 1?
---@return string?
function CosocketTcpSocket:sslhandshake()
	local deadline = self:getDeadline()

	while true do
		local ok, err = self.soc:dohandshake()
		if ok then
			return 1
		end

		local mode = get_wait_mode(err, "read")
		if not mode then
			return nil, err
		end

		ok, err = self:wait(mode, deadline)
		if not ok then
			return nil, err
		end
	end
end

---@param value number?
function CosocketTcpSocket:settimeout(value)
	self.timeout = value
	return self.soc:settimeout(0)
end

---@return string
---@return integer
function CosocketTcpSocket:getpeername()
	---@type string, integer, "inet"|"inet6"
	local ip, port, family = self.soc:getpeername()
	return ip, port
end

---@param timeout number?
---@return boolean
function CosocketTcpSocket:selectreceive(timeout)
	local recvt, _, err = self.scheduler.select({self.soc}, {}, timeout)
	return not not (recvt and recvt[1])
end

---@param timeout number?
---@return boolean
function CosocketTcpSocket:selectsend(timeout)
	local _, sendt, err = self.scheduler.select({}, {self.soc}, timeout)
	return not not (sendt and sendt[1])
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function CosocketTcpSocket:receive(pattern, prefix)
	local deadline = self:getDeadline()

	while true do
		local data, err, partial = self.soc:receive(pattern, prefix)
		if data then
			return data
		end

		local mode = get_wait_mode(err, "read")
		if not mode then
			return nil, err, partial
		end

		local ok
		ok, err = self:wait(mode, deadline)
		if not ok then
			return nil, err, partial
		end
		prefix = partial
	end
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function CosocketTcpSocket:send(data, i, j)
	local deadline = self:getDeadline()
	i = i or 1
	j = j or #data

	while true do
		local last_byte, err, partial = self.soc:send(data, i, j)
		if last_byte then
			return last_byte
		end

		local mode = get_wait_mode(err, "write")
		if not mode then
			return nil, err, partial
		end

		local ok
		ok, err = self:wait(mode, deadline)
		if not ok then
			return nil, err, partial
		end

		i = (partial or i - 1) + 1
	end
end

---@return 1
function CosocketTcpSocket:close()
	self.scheduler:closeSocket(self.soc)
	return self.soc:close()
end

return CosocketTcpSocket
