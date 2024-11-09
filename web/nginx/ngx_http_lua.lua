--[[
	Reference:
	https://github.com/openresty/lua-nginx-module
	lua-nginx-module/src/ngx_http_lua_socket_tcp.h
	lua-nginx-module/src/ngx_http_lua_socket_tcp.c
	lua-nginx-module/src/ngx_http_lua_input_filters.c
]]

local socket_compile_pattern = require("web.nginx.socket_compile_pattern")
local socket_compiled_pattern_t = require("web.nginx.socket_compiled_pattern_t")

---@param s string
---@param i integer
---@return string
local function subchar0(s, i)
	return s:sub(i + 1, i + 1)
end

local ngx_http_lua = {}

---@param src ngx.buf_t
---@param buf_in ngx.buf_t
---@param rest_p {[1]: integer}
---@param bytes integer
---@return "ok"|"again"|"error"
function ngx_http_lua.read_bytes(src, buf_in, rest_p, bytes)
	if bytes == 0 then
		return "error"
	end

	if bytes >= rest_p[1] then
		buf_in.last = buf_in.last + rest_p[1]
		src.pos = src.pos + rest_p[1]
		rest_p[1] = 0

		return "ok"
	end

	buf_in.last = buf_in.last + bytes
	src.pos = src.pos + bytes
	rest_p[1] = rest_p[1] - bytes

	return "again"
end

---@param src ngx.buf_t
---@param buf_in ngx.buf_t
---@param bytes integer
---@return "ok"|"again"
function ngx_http_lua.read_all(src, buf_in, bytes)
	if bytes == 0 then
		return "ok"
	end

	buf_in.last = buf_in.last + bytes
	src.pos = src.pos + bytes

	return "again"
end

---@param src ngx.buf_t
---@param buf_in ngx.buf_t
---@param max integer
---@param bytes integer
---@return "ok"|"error"
function ngx_http_lua.read_any(src, buf_in, max, bytes)
	if bytes == 0 then
		return "error"
	end

	if bytes >= max then
		bytes = max
	end

	buf_in.last = buf_in.last + bytes
	src.pos = src.pos + bytes

	return "ok"
end

---@param src ngx.buf_t
---@param buf_in ngx.buf_t
---@param bytes integer
---@return "ok"|"again"|"error"
function ngx_http_lua.read_line(src, buf_in, bytes)
	if bytes == 0 then
		return "error"
	end

	local dst = buf_in.last

	while bytes > 0 do
		bytes = bytes - 1
		local c = src:charAtPos0()
		src.pos = src.pos + 1

		if c == "\n" then
			buf_in.last = dst
			return "ok"
		elseif c == "\r" then
		else
			buf_in:set(dst, c)
			dst = dst + 1
		end
	end

	buf_in.last = dst

	return "again"
end

--------------------------------------------------------------------------------

---@param u ngx_http_lua.socket_tcp_upstream_t
---@param bytes integer
---@return "ok"|"again"|"error"
function ngx_http_lua.socket_read_chunk(u, bytes)
	local rest_p = {u.rest}
	local rc = ngx_http_lua.read_bytes(u.buffer, u.buf_in, rest_p, bytes)
	u.rest = rest_p[1]
	if rc == "error" then
		u.ft_type.NGX_HTTP_LUA_SOCKET_FT_CLOSED = true
	end
	return rc
end

---@param u ngx_http_lua.socket_tcp_upstream_t
---@param bytes integer
---@return "ok"|"again"
function ngx_http_lua.socket_read_all(u, bytes)
	return ngx_http_lua.read_all(u.buffer, u.buf_in, bytes)
end

---@param u ngx_http_lua.socket_tcp_upstream_t
---@param bytes integer
---@return "ok"|"again"|"error"
function ngx_http_lua.socket_read_line(u, bytes)
	local rc = ngx_http_lua.read_line(u.buffer, u.buf_in, bytes)
	if rc == "error" then
		u.ft_type.NGX_HTTP_LUA_SOCKET_FT_CLOSED = true
	end
	return rc
end

---@param u ngx_http_lua.socket_tcp_upstream_t
---@param bytes integer
---@return "ok"|"again"|"error"
function ngx_http_lua.socket_read_any(u, bytes)
	local rc = ngx_http_lua.read_any(u.buffer, u.buf_in, u.rest, bytes)
	if rc == "error" then
		u.ft_type.NGX_HTTP_LUA_SOCKET_FT_CLOSED = true
	end
	return rc
end

--------------------------------------------------------------------------------

---@param u ngx_http_lua.socket_tcp_upstream_t
---@param bytes integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ngx_http_lua.socket_tcp_receiveany(u, bytes)
	if u.read_closed then
		return nil, "closed", ""
	end

	u.input_filter = ngx_http_lua.socket_read_any
	u.rest = bytes
	u.length = u.rest

	return ngx_http_lua.socket_tcp_receive_helper(u)
end

---@param u ngx_http_lua.socket_tcp_upstream_t
---@param pattern "*a"|"*l"|integer?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ngx_http_lua.socket_tcp_receive(u, pattern)
	if u.read_closed then
		return nil, "closed", ""
	end

	pattern = pattern or "*l"
	if type(pattern) == "string" then
		if pattern == "*l" then
			u.input_filter = ngx_http_lua.socket_read_line
		elseif pattern == "*a" then
			u.input_filter = ngx_http_lua.socket_read_all
		else
			error("bad pattern argument")
		end
		u.length = 0
		u.rest = 0
	elseif type(pattern) == "number" then
		local bytes = pattern
		assert(bytes >= 0, "bad number argument")
		if bytes == 0 then
			return ""
		end

		u.input_filter = ngx_http_lua.socket_read_chunk
		u.length = bytes
		u.rest = u.length
	else
		error("bad argument")
	end

	return ngx_http_lua.socket_tcp_receive_helper(u)
end

--------------------------------------------------------------------------------

---@param u ngx_http_lua.socket_tcp_upstream_t
---@param data table
function ngx_http_lua.socket_tcp_read_prepare(u, data)
	if u.input_filter_ctx == data then
		return
	end

	if not u.input_filter_ctx or u.input_filter_ctx == u then
		u.input_filter_ctx = data
		return
	end

	local cp = u.input_filter_ctx
	---@cast cp ngx_http_lua.socket_compiled_pattern_t

	u.input_filter_ctx = data

	cp.upstream = nil

	if cp.state <= 0 then
		return
	end

	local b = u.buffer

	if b.pos - b.start >= cp.state then
		b.pos = b.pos - cp.state
		u.buf_in.pos = b.pos
		u.buf_in.last = b.pos
		cp.state = 0
		return
	end

	-- not implemented
	error("pending data in multiple buffers")
end

---@param u ngx_http_lua.socket_tcp_upstream_t
---@return "ok"|"error"?
function ngx_http_lua.socket_tcp_receive_helper(u)
	if not u.buf_in then
		error("not implemented")
	end

	ngx_http_lua.socket_tcp_read_prepare(u, u)

	local rc = ngx_http_lua.socket_tcp_read(u)

	if u.buf_in.pos == u.buf_in.last then
		u.ft_type.NGX_HTTP_LUA_SOCKET_FT_CLOSED = true
	end

	return ngx_http_lua.socket_tcp_receive_retval_handler(u)
end

---@param u ngx_http_lua.socket_tcp_upstream_t
---@param ft_type {[string]: true}
---@return nil
---@return "timeout"|"closed"|"error"
function ngx_http_lua.socket_prepare_error_retvals(u, ft_type)
	if ft_type.NGX_HTTP_LUA_SOCKET_FT_TIMEOUT then
		return nil, "timeout"
	elseif ft_type.NGX_HTTP_LUA_SOCKET_FT_CLOSED then
		return nil, "closed"
	end
	return nil, "error"
end

---@param u ngx_http_lua.socket_tcp_upstream_t
function ngx_http_lua.socket_tcp_finalize_read_part(u)
	u.read_closed = true
end

---@param u ngx_http_lua.socket_tcp_upstream_t
function ngx_http_lua.socket_read_error_retval_handler(u)
	local ft_type = u.ft_type
	u.ft_type = {}

	if u.no_close then
		u.no_close = false
	else
		ngx_http_lua.socket_tcp_finalize_read_part(u)
	end

	return ngx_http_lua.socket_prepare_error_retvals(u, ft_type)
end

---@param u ngx_http_lua.socket_tcp_upstream_t
function ngx_http_lua.socket_tcp_receive_retval_handler(u)
	if next(u.ft_type) then
		if u.ft_type.NGX_HTTP_LUA_SOCKET_FT_TIMEOUT then
			u.no_close = true
		end

		if u.buf_in then
			local data = ngx_http_lua.socket_push_input_data(u)
			local _, err = ngx_http_lua.socket_read_error_retval_handler(u)
			return nil, err, data
		end

		return ngx_http_lua.socket_read_error_retval_handler(u)
	end

	return ngx_http_lua.socket_push_input_data(u)
end

---@param u ngx_http_lua.socket_tcp_upstream_t
function ngx_http_lua.socket_push_input_data(u)
	local b = u.buf_in
	local res = b:sub()

	if u.buffer.pos == u.buffer.last then
		u.buffer.pos = u.buffer.start
		u.buffer.last = u.buffer.start
	end

	if u.buf_in then
		u.buf_in.last = u.buffer.pos
		u.buf_in.pos = u.buffer.pos
	end

	return res
end

---@param u ngx_http_lua.socket_tcp_upstream_t
function ngx_http_lua.socket_add_input_buffer(u)
	u.buf_in._end = 1024
	u.buffer._end = 1024
end

---@param u ngx_http_lua.socket_tcp_upstream_t
function ngx_http_lua.socket_read_handler(u, size)
	local data, err, partial = u.soc:receive(size)

	if (data or partial) == "" and err == "timeout" then
		u.ft_type.NGX_HTTP_LUA_SOCKET_FT_TIMEOUT = true
	end

	return data, err, partial
end

---@param u ngx_http_lua.socket_tcp_upstream_t
---@return "ok"|"again"|"error"
function ngx_http_lua.socket_tcp_read(u)
	---@type "ok"|"again"|"error"
	local rc = "ok"
	local b = u.buffer
	local read = 0

	while true do
		local size = b.last - b.pos

		if size > 0 or u.eof then
			---@type "ok"|"again"|"error"
			rc = u.input_filter(u.input_filter_ctx, size)

			if rc == "ok" then
				return "ok"
			end

			if rc == "error" then
				return "error"
			end

			goto continue
		end

		-- if read > 0 then
		-- 	rc = "again"
		-- 	break
		-- end

		size = b._end - b.last

		if size == 0 then
			ngx_http_lua.socket_add_input_buffer(u)
			b = u.buffer
			size = b._end - b.last
		end

		local data, err, partial = ngx_http_lua.socket_read_handler(u, size)
		data = data or partial
		local n = #data
		b.data = b.data:sub(1, b.last) .. data
		u.buf_in.data = u.buf_in.data:sub(1, u.buf_in.last) .. data

		if n == 0 and err == "timeout" then
			n = "again"
		end

		if n == "again" then
			rc = "again"
			break
		end

		read = 1

		if n == 0 then
			u.eof = true

			goto continue
		end

		if n == "error" then
			return "error"
		end

		b.last = b.last + n

		::continue::
	end

	return rc
end

---@param u ngx_http_lua.socket_tcp_upstream_t
---@param len integer
---@param prefix integer
---@param old_state integer
function ngx_http_lua.socket_add_pending_data(u, len, prefix, old_state)
	local pos = u.buffer.pos
	local last = pos + len
	local b = u.buf_in

	if last - b.last == old_state then
		b.last = b.last + prefix
		return
	end

	b.pos = last
	b.last = last
end

---@param cp ngx_http_lua.socket_compiled_pattern_t
---@param bytes integer
---@return "ok"|"again"|"error"
function ngx_http_lua.socket_read_until(cp, bytes)
	local u = cp.upstream
	local pat = cp.pattern
	local pat_len = #pat
	local state = cp.state
	local old_state = 0
	local matched = false

	if bytes == 0 then
		u.ft_type.NGX_HTTP_LUA_SOCKET_FT_CLOSED = true
		return "error"
	end

	local b = u.buffer

	local i = 0
	while i < bytes do
		local c = b:charAtPos0(i)

		if c == subchar0(pat, state) then
			i = i + 1
			state = state + 1

			if state == pat_len then
				b.pos = b.pos + i

				if u.length > 0 then
					cp.state = -1
				else
					cp.state = 0
				end

				if cp.inclusive then
					ngx_http_lua.socket_add_pending_data(u, 0, state, state)
				end

				return "ok"
			end

			goto continue
		end

		if state == 0 then
			u.buf_in.last = u.buf_in.last + 1
			i = i + 1

			if u.length > 0 then
				u.rest = u.rest - 1
				if u.rest == 0 then
					cp.state = state
					b.pos = b.pos + i
					return "ok"
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
			ngx_http_lua.socket_add_pending_data(u, i, state, state)

			if u.length > 0 then
				if u.rest <= state then
					u.rest = 0
					cp.state = 0
					b.pos = b.pos + i
					return "ok"
				else
					u.rest = u.rest - state
				end
			end

			state = 0
			goto continue
		end

		local pending_len = old_state + 1 - state
		ngx_http_lua.socket_add_pending_data(u, i, pending_len, old_state)

		i = i + 1

		if u.length > 0 then
			if u.rest <= pending_len then
				u.rest = 0
				cp.state = state
				b.pos = b.pos + i
				return "ok"
			else
				u.rest = u.rest - pending_len
			end
		end

		::continue::
	end

	b.pos = b.pos + i
	cp.state = state

	return "again"
end

---@param u ngx_http_lua.socket_tcp_upstream_t
---@param pattern string
---@param options {inclusive: boolean?}?
---@return fun(size: integer?): string?, "closed"|"timeout"?, string?
function ngx_http_lua.socket_tcp_receiveuntil(u, pattern, options)
	assert(#pattern > 0, "pattern is empty")
	local inclusive = options and options.inclusive or false

	local cp = socket_compiled_pattern_t()
	socket_compile_pattern(pattern, cp)
	cp.inclusive = inclusive

	return function(size)
		return ngx_http_lua.socket_receiveuntil_iterator(u, cp, size)
	end
end

---@param u ngx_http_lua.socket_tcp_upstream_t
---@param cp ngx_http_lua.socket_compiled_pattern_t
---@param size integer?
function ngx_http_lua.socket_receiveuntil_iterator(u, cp, size)
	local bytes = 0
	if size and size > 0 then
		bytes = size
	end

	if u.read_closed then
		return nil, "closed", ""
	end

	u.input_filter = ngx_http_lua.socket_read_until

	if cp.state == -1 then
		cp.state = 0
		return nil, nil, nil
	end

	cp.upstream = u
	-- cp.pattern = pattern

	u.length = bytes
	u.rest = u.length

	ngx_http_lua.socket_tcp_read_prepare(u, cp)

	local rc = ngx_http_lua.socket_tcp_read(u)

	return ngx_http_lua.socket_tcp_receive_retval_handler(u)
end

return ngx_http_lua
