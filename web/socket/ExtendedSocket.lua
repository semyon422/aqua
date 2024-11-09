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
	self.upstream.soc = soc
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:receive(pattern, prefix)
	assert(not prefix, "not implemented")
	return ngx_http_lua.socket_tcp_receive(self.upstream, pattern)
end

---@param max integer
---@return string?
---@return "closed"|"timeout"?
function ExtendedSocket:receiveany(max)
	return ngx_http_lua.socket_tcp_receiveany(self.upstream, max)
end

---@param pattern string
---@param options {inclusive: boolean?}?
---@return fun(size: integer?): string?, "closed"|"timeout"?, string?
function ExtendedSocket:receiveuntil(pattern, options)
	return ngx_http_lua.socket_tcp_receiveuntil(self.upstream, pattern, options)
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
