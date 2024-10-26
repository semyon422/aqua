local IExtendedSocket = require("web.socket.IExtendedSocket")
local socket_compile_pattern = require("web.nginx.socket_compile_pattern")
local socket_compiled_pattern_t = require("web.nginx.socket_compiled_pattern_t")

---@param s string
---@param i integer
---@return string
local function subchar0(s, i)
	return s:sub(i + 1, i + 1)
end

---@class web.ExtendedSocket: web.IExtendedSocket
---@operator call: web.ExtendedSocket
---@field remainder string
local ExtendedSocket = IExtendedSocket + {}

---@param soc web.ISocket
function ExtendedSocket:new(soc)
	self.soc = soc
	self.remainder = ""
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

---@param s string
---@param pattern string
---@return integer?
local function find_ambiguity(s, pattern)
	for i = 2, #pattern do
		local start = #s - #pattern + i
		if s:sub(start) == pattern:sub(1, #pattern - i + 1) then
			return start
		end
	end
end

assert(find_ambiguity("qwerty", "rtyuio") == 4)
assert(not find_ambiguity("qwertyuiop", "rty"))
assert(not find_ambiguity("qwerty", "rty"))
assert(not find_ambiguity("qwerty", "qwe"))
assert(not find_ambiguity("qwerty", "qwerty"))
assert(find_ambiguity("qwe", "qwerty") == 1)

---@param s string
---@param pattern string
---@return integer?
local function reverse_find_ambiguity(s, pattern)
	for i = #pattern, 2, -1 do
		local start = #s - #pattern + i
		if s:sub(start) == pattern:sub(1, #pattern - i + 1) then
			return start
		end
	end
end

--[[
	Reference:
	lua-nginx-module/src/ngx_http_lua_socket_tcp.c
	- ngx_http_lua_socket_tcp_receiveuntil
	- ngx_http_lua_socket_receiveuntil_iterator
	- ngx_http_lua_socket_read_until
]]

---@param pattern string
---@param options {inclusive: boolean?}?
---@return fun(size: integer?): string?, "closed"|"timeout"?, string?
function ExtendedSocket:receiveuntil(pattern, options)
	assert(#pattern > 0, "pattern is empty")
	local inclusive = options and options.inclusive

	local cp = socket_compiled_pattern_t()
	socket_compile_pattern(pattern, cp)

	local state = 0

	return function(size)
		local rest = size

		---@type string[]
		local buffer = {}

		::again::

		local soc = self.soc
		---@cast soc web.StringSocket

		local buf = soc.remainder

		local old_state = 0

		local pat = cp.pattern
		local pat_len = #pat
		state = cp.state
		local matched = false
		local pending_len = 0

		if state == -1 then
			cp.state = 0
			return
		end

		if buf == "" then
			local ret = table.concat(buffer)
			buffer = {}
			local err = soc.closed and "closed" or "timeout"
			return nil, err, ret .. buf
		end

		local i = 0
		while i < #buf do
			local c = subchar0(buf, i)

			if c == subchar0(pat, state) then
				i = i + 1
				state = state + 1

				if state == pat_len then
					self.soc:receive(i)

					if size then
						cp.state = -1
					else
						cp.state = 0
					end

					if inclusive then
						table.insert(buffer, pat)
					end

					local ret = table.concat(buffer)
					buffer = {}
					return ret
				end

				goto continue
			end

			if state == 0 then
				table.insert(buffer, c)
				i = i + 1

				if size then
					rest = rest - 1
					if rest == 0 then
						cp.state = state
						self.soc:receive(i)
						local ret = table.concat(buffer)
						buffer = {}
						return ret
					end
				end

				goto continue
			end

			matched = false

			if cp.recovering and state >= 2 then
				local edge = cp.recovering[state - 2]
				while edge do
					if edge.chr == c then
						old_state = state
						state = edge.new_state
						matched = true
						break
					end

					edge = edge.next
				end
			end

			if not matched then
				table.insert(buffer, pat:sub(1, state))

				if size then
					if rest <= state then
						rest = 0
						cp.state = 0
						self.soc:receive(i)
						local ret = table.concat(buffer)
						buffer = {}
						return ret
					else
						rest = rest - state
					end
				end

				state = 0
				goto continue
			end

			pending_len = old_state + 1 - state
			table.insert(buffer, pat:sub(1, pending_len))

			i = i + 1

			if size then
				if rest <= pending_len then
					rest = 0
					cp.state = state
					self.soc:receive(i)
					local ret = table.concat(buffer)
					buffer = {}
					return ret
				else
					rest = rest - pending_len
				end
			end

			::continue::
		end

		self.soc:receive(i)
		cp.state = state

		goto again
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
