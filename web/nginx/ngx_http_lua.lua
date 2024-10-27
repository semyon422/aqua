--[[
	Reference:
	https://github.com/openresty/lua-nginx-module
	lua-nginx-module/src/ngx_http_lua_socket_tcp.h
	lua-nginx-module/src/ngx_http_lua_socket_tcp.c
	lua-nginx-module/src/ngx_http_lua_input_filters.c
]]

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
---@return "ok"|"again"|"error"
function ngx_http_lua.read_all(src, buf_in, bytes)
	if bytes == 0 then
		return "error"
	end

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
	return rc
end

---@param u ngx_http_lua.socket_tcp_upstream_t
---@param bytes integer
---@return "ok"|"again"|"error"
function ngx_http_lua.socket_read_all(u, bytes)
	return ngx_http_lua.read_all(u.buffer, u.buf_in, bytes)
end

---@param u ngx_http_lua.socket_tcp_upstream_t
---@param bytes integer
---@return "ok"|"again"|"error"
function ngx_http_lua.socket_read_line(u, bytes)
	return ngx_http_lua.read_line(u.buffer, u.buf_in, bytes)
end

---@param u ngx_http_lua.socket_tcp_upstream_t
---@param bytes integer
---@return "ok"|"again"|"error"
function ngx_http_lua.socket_read_any(u, bytes)
	return ngx_http_lua.read_any(u.buffer, u.buf_in, u.rest, bytes)
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
---@return "ok"|"again"|"error"
function ngx_http_lua.socket_tcp_read(u)

	local b = u.buffer
	local read = 0

	while true do
		local size = b.last - b.pos

		if size > 0 then  -- or u.eof
			---@type string
			local rc = u.input_filter(u.input_filter_ctx, size)

			if rc == "ok" then

				-- ngx_http_lua.socket_handle_read_success
				return "ok"
			end

			if rc == "error" then
				-- ngx_http_lua.socket_handle_read_error
				return "error"
			end

			goto continue
		end

		::continue::
	end
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

return ngx_http_lua
