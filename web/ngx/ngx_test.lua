local ngx_http_lua = require("web.ngx.ngx_http_lua")
local socket_tcp_upstream_t = require("web.ngx.socket_tcp_upstream_t")

---@param data string
---@param rc_on_zero ngx.return_code?
---@return ngx_http_lua.socket_tcp_upstream_t
local function new_upstream(data, rc_on_zero)
	local upstream = socket_tcp_upstream_t()

	---@type string
	local chunk

	---@param b ngx.buf_t
	---@param offset integer
	---@param size integer
	---@return integer|ngx.return_code
	function upstream:recv(b, offset, size)
		chunk, data = data:sub(1, size), data:sub(size + 1)

		if chunk == "" then
			return rc_on_zero or 0
		end

		assert(#chunk <= size)
		b:copy(offset, chunk, #chunk)

		return #chunk
	end

	return upstream
end

local test = {}

---@param t testing.T
function test.receive_size(t)
	local u = new_upstream("qwertyuio")
	u.buffer_size = 3

	t:eq(ngx_http_lua.socket_tcp_receive(u, 7), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "qwertyu")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")

	t:eq(ngx_http_lua.socket_tcp_receive(u, 10), "error")
	t:eq(ngx_http_lua.socket_push_input_data(u), "io")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
end

---@param t testing.T
function test.receive_size_again(t)
	local u = new_upstream("qwertyuio", "again")
	u.buffer_size = 3

	t:eq(ngx_http_lua.socket_tcp_receive(u, 7), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "qwertyu")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")

	t:eq(ngx_http_lua.socket_tcp_receive(u, 10), "again") -- <--
	t:eq(ngx_http_lua.socket_push_input_data(u), "io")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
end

---@param t testing.T
function test.receive_line_1(t)
	local u = new_upstream("qwertyuio")
	u.buffer_size = 3

	t:eq(ngx_http_lua.socket_tcp_receive(u, "*l"), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "error")
	t:eq(ngx_http_lua.socket_push_input_data(u), "qwertyuio")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
end

---@param t testing.T
function test.receive_line_1_again(t)
	local u = new_upstream("qwertyuio", "again")
	u.buffer_size = 3

	t:eq(ngx_http_lua.socket_tcp_receive(u, "*l"), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "again") -- <--
	t:eq(ngx_http_lua.socket_push_input_data(u), "qwertyuio")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
end

---@param t testing.T
function test.receive_line_2(t)
	local u = new_upstream("qwert\r\nyuio")
	u.buffer_size = 3

	t:eq(ngx_http_lua.socket_tcp_receive(u, "*l"), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "qwert")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")

	t:eq(ngx_http_lua.socket_tcp_receive(u, "*l"), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "error")
	t:eq(ngx_http_lua.socket_push_input_data(u), "yuio")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
end

---@param t testing.T
function test.receive_all(t)
	local u = new_upstream("qwertyuio")
	u.buffer_size = 3

	t:eq(ngx_http_lua.socket_tcp_receive(u, "*a"), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "qwertyuio")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
end

---@param t testing.T
function test.receive_all_again(t)
	local u = new_upstream("qwertyuio", "again")
	u.buffer_size = 3

	t:eq(ngx_http_lua.socket_tcp_receive(u, "*a"), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "again")
	t:eq(ngx_http_lua.socket_tcp_read(u), "again") -- <--
	t:eq(ngx_http_lua.socket_push_input_data(u), "qwertyuio")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
end

---@param t testing.T
function test.receive_any(t)
	local u = new_upstream("qwertyuio")
	u.buffer_size = 3

	t:eq(ngx_http_lua.socket_tcp_receiveany(u, 4), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "qwe")
	t:eq(ngx_http_lua.socket_tcp_receiveany(u, 2), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "rt")
	t:eq(ngx_http_lua.socket_tcp_receiveany(u, 2), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "y")
	t:eq(ngx_http_lua.socket_tcp_receiveany(u, 4), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "uio")
	t:eq(ngx_http_lua.socket_tcp_receiveany(u, 4), "error")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
end

---@param t testing.T
function test.receive_any_again(t)
	local u = new_upstream("qwertyuio", "again")
	u.buffer_size = 3

	t:eq(ngx_http_lua.socket_tcp_receiveany(u, 4), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "qwe")
	t:eq(ngx_http_lua.socket_tcp_receiveany(u, 2), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "rt")
	t:eq(ngx_http_lua.socket_tcp_receiveany(u, 2), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "y")
	t:eq(ngx_http_lua.socket_tcp_receiveany(u, 4), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "uio")
	t:eq(ngx_http_lua.socket_tcp_receiveany(u, 4), "again")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
end

---@param t testing.T
function test.receive_until_1(t)
	local u = new_upstream("qwertyuio")
	u.buffer_size = 3

	local reader = assert(ngx_http_lua.socket_tcp_receiveuntil(u, "i"))

	t:eq(reader(), "again")
	t:eq(reader(), "again")
	t:eq(reader(), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "qwertyu")
	t:eq(reader(), "error")
	t:eq(ngx_http_lua.socket_push_input_data(u), "o")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
end

---@param t testing.T
function test.receive_until_2(t)
	local u = new_upstream("qwertyuio")
	u.buffer_size = 3

	local reader = assert(ngx_http_lua.socket_tcp_receiveuntil(u, "i"))

	t:eq(reader(2), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "qw")
	t:eq(reader(2), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "er")
	t:eq(reader(3), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "tyu")
	t:eq(reader(3), "ok")
	t:eq(ngx_http_lua.socket_push_input_data(u), "")
end

return test
