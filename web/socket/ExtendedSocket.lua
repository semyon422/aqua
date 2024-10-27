local IExtendedSocket = require("web.socket.IExtendedSocket")
local socket_compile_pattern = require("web.nginx.socket_compile_pattern")
local socket_compiled_pattern_t = require("web.nginx.socket_compiled_pattern_t")
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
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:receive(pattern, prefix)
	assert(pattern == "*a" or pattern == "*l" or type(pattern) == "number", "invalid pattern")
	assert(not prefix, "not implemented")

	if type(pattern) == "number" then
		return self:receiveSize(pattern)
	elseif pattern == "*l" then
		return self:receiveLine()
	elseif pattern == "*a" then
		return self:receiveAll()
	end
end

---@private
---@param size integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:receiveSize(size)
	---@type string[]
	local buffer = {}

	local total = 0
	while true do
		local line, err, partial = self.soc:receive(1)

		local data = line or partial
		---@cast data string

		table.insert(buffer, data)
		total = total + #data

		if total == size then
			return table.concat(buffer)
		end

		if not line then
			return nil, err, table.concat(buffer)
		end
	end
end

---@private
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:receiveLine()
	---@type string[]
	local buffer = {}

	while true do
		local line, err, partial = self.soc:receive(1)

		local data = line or partial
		---@cast data string

		if data == "\n" then
			return (table.concat(buffer):gsub("\r", ""))
		end

		table.insert(buffer, data)

		if not line then
			return nil, err, (table.concat(buffer):gsub("\r", ""))
		end
	end
end

---@private
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:receiveAll()
	---@type string[]
	local buffer = {}

	while true do
		local line, err, partial = self.soc:receive(1)

		local data = line or partial
		---@cast data string

		table.insert(buffer, data)

		if err then
			local ret = table.concat(buffer)
			if err == "closed" and #ret > 0 then
				return ret
			end
			return nil, err, ret
		end
	end
end

---@param max integer
---@return string?
---@return "closed"|"timeout"?
function ExtendedSocket:receiveany(max)
	local line, err, partial = self.soc:receive(max)

	local data = line or partial
	---@cast data string

	if #data > 0 then
		return data
	end

	return nil, err
end

---@param pattern string
---@param options {inclusive: boolean?}?
---@return fun(size: integer?): string?, "closed"|"timeout"?, string?
function ExtendedSocket:receiveuntil(pattern, options)
	assert(#pattern > 0, "pattern is empty")
	local inclusive = options and options.inclusive or false

	local cp = socket_compiled_pattern_t()
	socket_compile_pattern(pattern, cp)
	cp.inclusive = inclusive

	cp.upstream = self.upstream

	local soc = self.soc
	---@cast soc web.BufferSocket

	return function(size)
		size = size or 0
		self.upstream.rest = size
		self.upstream.length = size

		local buf_in = self.upstream.buf_in
		buf_in:new(soc.remainder)

		local b = self.upstream.buffer
		b:new(soc.remainder)

		::again::

		if cp.state == -1 then
			cp.state = 0
			return
		end

		local rc = ngx_http_lua.socket_read_until(cp, b:size())
		if rc == "ok" then
			soc:receive(b.pos)
			return buf_in:sub()
		end

		if rc == "error" then
			local rem = soc.remainder
			soc.remainder = ""
			local err = soc.closed and "closed" or "timeout"
			return nil, err, buf_in:sub()
		end

		if rc == "again" then
			-- if soc.pos == #soc.remainder then
				local s = soc:receive(b.pos)
				local err = soc.closed and "closed" or "timeout"
				return nil, err, buf_in:sub()
			-- end
			-- goto again
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
