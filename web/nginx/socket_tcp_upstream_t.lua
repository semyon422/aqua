local class = require("class")
local ngx_buf_t = require("web.nginx.ngx_buf_t")

---@class ngx_http_lua.socket_tcp_upstream_t
---@operator call: ngx_http_lua.socket_tcp_upstream_t
---@field input_filter function
---@field input_filter_ctx table
local socket_tcp_upstream_t = class()

function socket_tcp_upstream_t:new()
	self.length = 0
	self.rest = 0
	self.buf_in = ngx_buf_t()  -- last input data buffer
	self.buffer = ngx_buf_t()  -- receive buffer
end

return socket_tcp_upstream_t
