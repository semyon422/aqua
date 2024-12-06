local IExtendedSocket = require("web.socket.IExtendedSocket")
local socket_tcp_upstream_t = require("web.ngx.socket_tcp_upstream_t")
local ngx_http_lua = require("web.ngx.ngx_http_lua")

---@class web.ExtendedSocket: web.IExtendedSocket
---@operator call: web.ExtendedSocket
---@field err "closed"|"timeout"?
local ExtendedSocket = IExtendedSocket + {}

-- cosocket mode
ExtendedSocket.cosocket = false

---@param soc web.ISocket
function ExtendedSocket:new(soc)
	self.soc = soc
	self.upstream = socket_tcp_upstream_t()
	self.last_bytes = 0

	local _self = self

	---@param b ngx.buf_t
	---@param offset integer
	---@param size integer
	---@return integer|"again"
	function self.upstream:recv(b, offset, size)
		local data, err = _self.soc:receiveany(size)
		assert(not err or err == "closed" or err == "timeout", err)

		if err == "timeout" then
			data = ""
		end

		if not data then
			_self.err = "closed"
			_self.last_bytes = 0
			return 0
		end

		local n = #data
		b:copy(offset, data, n)

		_self.err = "timeout"
		_self.last_bytes = n

		if n == 0 then
			return "again"
		end

		return n
	end
end

---@private
---@param rc ngx.return_code
---@param should_not_push boolean?
---@param not_nil boolean?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:handle_return(rc, should_not_push, not_nil)
	---@type string
	local data

	if rc == "ok" and not should_not_push then
		data = ngx_http_lua.socket_push_input_data(self.upstream)
	end

	if rc == "ok" then
		if data ~= "" or self.last_bytes ~= 0 then
			if not_nil then
				return data or ""
			end
			return data
		end
		return nil, self.err, ""
	end

	while rc == "again" do
		if self.cosocket then
			coroutine.yield("read")
		end
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
	local rc, should_not_push = ngx_http_lua.socket_tcp_receive(self.upstream, pattern)
	return self:handle_return(rc, should_not_push, true)
end

---@param max integer
---@return string?
---@return "closed"|"timeout"?
function ExtendedSocket:receiveany(max)
	local data, err = self:handle_return(ngx_http_lua.socket_tcp_receiveany(self.upstream, max))
	return data, err
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
	if not self.cosocket then
		return self.soc:send(data, i, j)
	end

	i, j = self:normalize_bounds(data, i, j)

	while true do
		local last_byte, err, _last_byte = self.soc:send(data, i, j)
		if err == "closed" then
			return nil, "closed", _last_byte
		end

		local byte = last_byte or _last_byte
		---@cast byte integer

		i = byte + 1
		if last_byte then
			return last_byte
		elseif err == "timeout" then
			coroutine.yield("write")
		end
	end
end

---@return 1
function ExtendedSocket:close()
	return self.soc:close()
end

return ExtendedSocket
