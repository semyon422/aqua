--[[
	Reference:
	https://github.com/openresty/lua-nginx-module
	lua-nginx-module/src/ngx_http_lua_socket_tcp.h
	lua-nginx-module/src/ngx_http_lua_socket_tcp.c
	lua-nginx-module/src/ngx_http_lua_input_filters.c
]]

local socket_compile_pattern = require("web.nginx.socket_compile_pattern")
local socket_compiled_pattern_t = require("web.nginx.socket_compiled_pattern_t")
local ngx_chain_t = require("web.nginx.ngx_chain_t")
local ngx_buf_t = require("web.nginx.ngx_buf_t")

local buffer_size = 1

---@type ngx.chain_t
local free_recv_bufs = nil

---@param s string
---@param i integer
---@return string
local function subchar0(s, i)
	return s:sub(i + 1, i + 1)
end

local ngx_http_lua = {}

---@param len integer
---@return ngx.chain_t
function ngx_http_lua.chain_get_free_buf(len)
	local free = free_recv_bufs

	---@type ngx.buf_t
	local b
	---@type ngx.chain_t
	local cl

	if free then
		cl = free
		free = cl.next
		cl.next = nil

		b = cl.buf
		local start = b.start
		local _end = b._end
		if _end - start >= len then
			b.start = start
			b.pos = start
			b.last = start
			b._end = _end

			return cl
		end

		if len == 0 then
			return cl
		end

		b.start = b:ngx_palloc(len)

		b._end = b.start + len

		b.pos = b.start
		b.last = b.start

		return cl
	end

	local cl = ngx_chain_t()
	cl.buf = ngx_buf_t(len)
	cl.next = nil

	return cl
end

--------------------------------------------------------------------------------

--- ngx_http_lua_read_bytes
---@param src ngx.buf_t
---@param buf_in ngx.chain_t
---@param rest_p {[1]: integer}
---@param bytes integer
---@return "ok"|"again"|"error"
function ngx_http_lua.read_bytes(src, buf_in, rest_p, bytes)
	if bytes == 0 then
		return "error"
	end

	if bytes >= rest_p[1] then
		buf_in.buf.last = buf_in.buf.last + rest_p[1]
		src.pos = src.pos + rest_p[1]
		rest_p[1] = 0

		return "ok"
	end

	buf_in.buf.last = buf_in.buf.last + bytes
	src.pos = src.pos + bytes
	rest_p[1] = rest_p[1] - bytes

	return "again"
end

--- ngx_http_lua_read_all
---@param src ngx.buf_t
---@param buf_in ngx.chain_t
---@param bytes integer
---@return "ok"|"again"
function ngx_http_lua.read_all(src, buf_in, bytes)
	if bytes == 0 then
		return "ok"
	end

	buf_in.buf.last = buf_in.buf.last + bytes
	src.pos = src.pos + bytes

	return "again"
end

--- ngx_http_lua_read_any
---@param src ngx.buf_t
---@param buf_in ngx.chain_t
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

	buf_in.buf.last = buf_in.buf.last + bytes
	src.pos = src.pos + bytes

	return "ok"
end

--- ngx_http_lua_read_line
---@param src ngx.buf_t
---@param buf_in ngx.chain_t
---@param bytes integer
---@return "ok"|"again"|"error"
function ngx_http_lua.read_line(src, buf_in, bytes)
	if bytes == 0 then
		return "error"
	end

	local dst = buf_in.buf.last

	while bytes > 0 do
		bytes = bytes - 1
		local c = src:charAtPos0()
		src.pos = src.pos + 1

		if c == "\n" then
			buf_in.buf.last = dst
			return "ok"
		elseif c == "\r" then
		else
			-- *dst++ = c;
			buf_in.buf:set(dst, c)
			dst = dst + 1
		end
	end

	buf_in.buf.last = dst

	return "again"
end

--------------------------------------------------------------------------------

--- ngx_http_lua_socket_read_chunk
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

--- ngx_http_lua_socket_read_all
---@param u ngx_http_lua.socket_tcp_upstream_t
---@param bytes integer
---@return "ok"|"again"
function ngx_http_lua.socket_read_all(u, bytes)
	return ngx_http_lua.read_all(u.buffer, u.buf_in, bytes)
end

--- ngx_http_lua_socket_read_line
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

--- ngx_http_lua_socket_read_any
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

	assert(type(bytes) == "number" and bytes > 0, "bad max argument")

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
		u.buf_in.buf.pos = b.pos
		u.buf_in.buf.last = b.pos
		cp.state = 0
		return
	end

	local size = b:size()

	local new_cl = ngx_http_lua.chain_get_free_buf(cp.state + size)

	b:clone_from(new_cl.buf)

	b.last = b:ngx_copy(b.last, cp.pattern, cp.state)
	b.last = b:ngx_copy(b.last, u.buf_in.buf:get_ptr(u.buf_in.buf.pos), size)

	u.buf_in.next = free_recv_bufs
	free_recv_bufs = u.buf_in

	u.bufs_in = new_cl
	u.buf_in = new_cl

	cp.state = 0
end

---@param u ngx_http_lua.socket_tcp_upstream_t
---@return "ok"|"error"?
function ngx_http_lua.socket_tcp_receive_helper(u)
	if not u.bufs_in then
		u.bufs_in = ngx_http_lua.chain_get_free_buf(buffer_size)
		u.buf_in = u.bufs_in
		u.buffer = u.buf_in.buf:clone()
	end

	ngx_http_lua.socket_tcp_read_prepare(u, u)

	local rc = ngx_http_lua.socket_tcp_read(u)

	if rc == "error" then
		return ngx_http_lua.socket_tcp_receive_retval_handler(u)
	end

	if rc == "ok" then
		return ngx_http_lua.socket_tcp_receive_retval_handler(u)
	end

	-- !!!!!!!!!!!!!!

	if u.buf_in.pos == u.buf_in.last then
		u.ft_type.NGX_HTTP_LUA_SOCKET_FT_CLOSED = true
	end

	return ngx_http_lua.socket_tcp_receive_retval_handler(u)
end

--- ngx_http_lua_socket_prepare_error_retvals
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

--- ngx_http_lua_socket_tcp_finalize_read_part
---@param u ngx_http_lua.socket_tcp_upstream_t
function ngx_http_lua.socket_tcp_finalize_read_part(u)
	u.read_closed = true
end

--- ngx_http_lua_socket_read_error_retval_handler
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

--- ngx_http_lua_socket_tcp_receive_retval_handler
---@param u ngx_http_lua.socket_tcp_upstream_t
function ngx_http_lua.socket_tcp_receive_retval_handler(u)
	if next(u.ft_type) then
		if u.ft_type.NGX_HTTP_LUA_SOCKET_FT_TIMEOUT then
			u.no_close = true
		end

		if u.bufs_in then
			local data = ngx_http_lua.socket_push_input_data(u)
			local _, err = ngx_http_lua.socket_read_error_retval_handler(u)
			return nil, err, data
		end

		local n, err = ngx_http_lua.socket_read_error_retval_handler(u)
		return n, err, ""
	end

	return ngx_http_lua.socket_push_input_data(u)
end

--- ngx_http_lua_socket_push_input_data
---@param u ngx_http_lua.socket_tcp_upstream_t
---@return string
function ngx_http_lua.socket_push_input_data(u)
	---@type ngx.buf_t
	local b
	local nbufs = 0
	---@type table, string
	local ll_t, ll_k
	---@type string[]
	local luabuf = {}

	local cl = u.bufs_in
	while cl do
		b = cl.buf
		luabuf[nbufs + 1] = b:sub()
		if cl.next then
			ll_t, ll_k = cl, "next"
		end
		nbufs = nbufs + 1
		cl = cl.next
	end

	local res = table.concat(luabuf)

	if nbufs > 1 and ll_t then
		-- ll_t[ll_k] = free_recv_bufs
		-- free_recv_bufs = u.bufs_in
		u.bufs_in = u.buf_in
	end

	if u.buffer.pos == u.buffer.last then
		u.buffer.pos = u.buffer.start
		u.buffer.last = u.buffer.start
	end

	if u.buf_in then
		u.buf_in.buf.last = u.buffer.pos
		u.buf_in.buf.pos = u.buffer.pos
	end

	return res
end

--- ngx_http_lua_socket_add_input_buffer
---@param u ngx_http_lua.socket_tcp_upstream_t
function ngx_http_lua.socket_add_input_buffer(u)
	local cl = ngx_http_lua.chain_get_free_buf(buffer_size)
	u.buf_in.next = cl
	u.buf_in = cl
	u.buffer = cl.buf:clone()
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
		b:ngx_copy(b.last, data, n)

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

--- ngx_http_lua_socket_add_pending_data
---@param u ngx_http_lua.socket_tcp_upstream_t
---@param pos integer
---@param len integer
---@param pat string
---@param prefix integer
---@param old_state integer
function ngx_http_lua.socket_add_pending_data(u, pos, len, pat, prefix, old_state)
	local last = pos + len
	local b = u.buf_in.buf

	if last - b.last == old_state then
		b.last = b.last + prefix
		return
	end

	ngx_http_lua.socket_insert_buffer(u, pat, prefix)

	b.pos = last
	b.last = last
end

--- ngx_http_lua_socket_insert_buffer
---@param u ngx_http_lua.socket_tcp_upstream_t
---@param pat string
---@param prefix integer
function ngx_http_lua.socket_insert_buffer(u, pat, prefix)
	---@type table, string
	local ll_t, ll_k

	local size = prefix
	if size <= buffer_size then
		size = buffer_size
	end

	local new_cl = ngx_http_lua.chain_get_free_buf(size)

	local b = new_cl.buf

	b.last = b:ngx_copy(b.last, pat, prefix)

	ll_t, ll_k = u, "bufs_in"
	local cl = u.bufs_in
	while cl.next do
		ll_t, ll_k = cl, "next"
		cl = cl.next
	end

	ll_t[ll_k] = new_cl
	new_cl.next = u.buf_in
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
					ngx_http_lua.socket_add_pending_data(u, b.pos, 0, pat, state, state)
				end

				return "ok"
			end

			goto continue
		end

		if state == 0 then
			u.buf_in.buf.last = u.buf_in.buf.last + 1
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
			ngx_http_lua.socket_add_pending_data(u, b.pos, i, pat, state, state)

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
		ngx_http_lua.socket_add_pending_data(u, b.pos, i, pat, pending_len, old_state)

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

	if not u.bufs_in then
		u.bufs_in = ngx_http_lua.chain_get_free_buf(buffer_size)
		u.buf_in = u.bufs_in
		u.buffer = u.buf_in.buf:clone()
	end

	u.length = bytes
	u.rest = u.length

	ngx_http_lua.socket_tcp_read_prepare(u, cp)

	local rc = ngx_http_lua.socket_tcp_read(u)

	if rc == "error" then
		return ngx_http_lua.socket_tcp_receive_retval_handler(u)
	end

	if rc == "ok" then
		return ngx_http_lua.socket_tcp_receive_retval_handler(u)
	end

	return ngx_http_lua.socket_tcp_receive_retval_handler(u)
end

return ngx_http_lua
