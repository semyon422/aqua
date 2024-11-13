local class = require("class")
local ngx_buf_t = require("web.nginx.ngx_buf_t")
local ngx_chain_t = require("web.nginx.ngx_chain_t")

---@class ngx_http_lua.socket_tcp_upstream_t
---@operator call: ngx_http_lua.socket_tcp_upstream_t
---@field input_filter function
---@field input_filter_ctx table
---@field soc web.ISocket
---@field ft_type {[string]: true}
---@field bufs_in ngx.chain_t ngx_chain_t*, input data buffers
---@field buf_in ngx.chain_t ngx_chain_t*, last input data buffer
---@field buffer ngx.buf_t ngx_buf_t, receive buffer
local socket_tcp_upstream_t = class()

function socket_tcp_upstream_t:new()
	self.ft_type = {}
	self.length = 0
	self.rest = 0
	self.eof = false
	self.no_close = false
	self.read_closed = false
	self.buffer_size = 8192
	-- self.bufs_in = ngx_chain_t()  -- input data buffers
	-- self.buf_in = ngx_chain_t()  -- last input data buffer
	-- self.buffer = ngx_buf_t()  -- receive buffer
end

---@param b ngx.buf_t
---@param offset integer
---@param size integer
function socket_tcp_upstream_t:recv(b, offset, size)  -- n = c->recv(c, b->last, size);
	error("not implemented")
end

return socket_tcp_upstream_t
