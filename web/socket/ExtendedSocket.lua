local IExtendedSocket = require("web.socket.IExtendedSocket")
local socket_tcp_upstream_t = require("web.nginx.socket_tcp_upstream_t")
local ngx_http_lua = require("web.nginx.ngx_http_lua")

---@class web.ExtendedSocket: web.IExtendedSocket
---@operator call: web.ExtendedSocket
---@field err "closed"|"timeout"?
local ExtendedSocket = IExtendedSocket + {}

---@param soc web.ISocket
function ExtendedSocket:new(soc)
	self.soc = soc
	self.upstream = socket_tcp_upstream_t()

	local _self = self

	---@param b ngx.buf_t
	---@param offset integer
	---@param size integer
	---@return integer|"again"
	function self.upstream:recv(b, offset, size)
		local data, err, partial = soc:receive(size)
		data = data or partial
		---@cast data string

		local n = #data
		b:copy(offset, data, n)

		_self.err = err

		if n == 0 and err == "timeout" then
			return "again"
		end

		return n
	end
end

---@private
---@param rc ngx.return_code
---@param data string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:handle_return(rc, data)
	if rc == "ok" then
		return data
	end
	return nil, self.err, data
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:receive(pattern, prefix)
	assert(not prefix, "not implemented")
	local rc, data = ngx_http_lua.socket_tcp_receive(self.upstream, pattern)
	if pattern == "*a" and (data == "" or self.upstream.err == "timeout") then
		rc = "error"
	end
	return self:handle_return(rc, data)
end

---@param max integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:receiveany(max)
	return self:handle_return(ngx_http_lua.socket_tcp_receiveany(self.upstream, max))
end

---@param pattern string
---@param options {inclusive: boolean?}?
---@return fun(size: integer?): string?, "closed"|"timeout"?, string?
function ExtendedSocket:receiveuntil(pattern, options)
	local iterator = assert(ngx_http_lua.socket_tcp_receiveuntil(self.upstream, pattern, options))
	return function(max)
		return self:handle_return(iterator(max))
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
