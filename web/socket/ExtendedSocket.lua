local IExtendedSocket = require("web.socket.IExtendedSocket")
local socket_tcp_upstream_t = require("web.nginx.socket_tcp_upstream_t")
local ngx_http_lua = require("web.nginx.ngx_http_lua")

---@class web.ExtendedSocket: web.IExtendedSocket
---@operator call: web.ExtendedSocket
---@field remainder string
local ExtendedSocket = IExtendedSocket + {}

---@param soc web.ISocket
function ExtendedSocket:new(soc)
	self.soc = soc
	self.upstream = socket_tcp_upstream_t()

	---@param b ngx.buf_t
	---@param offset integer
	---@param size integer
	function self.upstream:recv(b, offset, size)
		local data, err, partial = soc:receive(size)
		data = data or partial
		local n = #data
		b:ngx_copy(offset, data, n)
		if n == 0 and err == "timeout" then
			n = "again"
		end

		self.err = err

		return n
	end
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:receive(pattern, prefix)
	assert(not prefix, "not implemented")
	local rc, data = ngx_http_lua.socket_tcp_receive(self.upstream, pattern)
	if pattern == "*a" then
		if data ~= "" and self.upstream.err ~= "timeout" then
			return data
		end
		return nil, self.upstream.err, data
	end
	if rc == "ok" then
		return data
	else
		return nil, self.upstream.err, data
	end
end

---@param max integer
---@return string?
---@return "closed"|"timeout"?
function ExtendedSocket:receiveany(max)
	local rc, data = ngx_http_lua.socket_tcp_receiveany(self.upstream, max)
	if rc == "ok" then
		return data
	else
		return nil, self.upstream.err, data
	end
end

---@param pattern string
---@param options {inclusive: boolean?}?
---@return fun(size: integer?): string?, "closed"|"timeout"?, string?
function ExtendedSocket:receiveuntil(pattern, options)
	local iterator = ngx_http_lua.socket_tcp_receiveuntil(self.upstream, pattern, options)
	return function(max)
		local rc, data = iterator(max)
		if not data then
			return data
		end
		if rc == "ok" then
			return data
		else
			return nil, self.upstream.err, data
		end
	end
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function ExtendedSocket:send(data, i, j)
	return self.soc:send(data:sub(i or 1, j))
end

---@return 1
function ExtendedSocket:close()
	return self.soc:close()
end

return ExtendedSocket
