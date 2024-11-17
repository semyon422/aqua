local IExtendedSocket = require("web.socket.IExtendedSocket")
local socket_tcp_upstream_t = require("web.ngx.socket_tcp_upstream_t")
local ngx_http_lua = require("web.ngx.ngx_http_lua")

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
		_self.last_bytes = n

		if n == 0 and err == "timeout" then
			return "again"
		end

		return n
	end
end

---@private
---@param rc ngx.return_code
---@param should_not_push boolean
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:handle_return(rc, should_not_push)
	---@type string
	local data

	if rc == "ok" and not should_not_push then
		data = ngx_http_lua.socket_push_input_data(self.upstream)
	end

	if rc == "ok" then
		if data ~= "" or self.last_bytes ~= 0 then
			return data
		end
		return nil, self.err, ""
	end

	while rc == "again" do
		rc = ngx_http_lua.socket_tcp_read(self.upstream)
		if self.last_bytes == 0 then
			break
		end
	end

	data = data or ngx_http_lua.socket_push_input_data(self.upstream)

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
	return self:handle_return(ngx_http_lua.socket_tcp_receive(self.upstream, pattern))
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
	return self.soc:send(data, i, j)
end

---@return 1
function ExtendedSocket:close()
	return self.soc:close()
end

return ExtendedSocket
