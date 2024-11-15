local class = require("class")
local ngx_str_t = require("web.ngx.ngx_str_t")

---@class ngx_http_lua.socket_compiled_pattern_t
---@operator call: ngx_http_lua.socket_compiled_pattern_t
---@field upstream ngx_http_lua.socket_tcp_upstream_t ngx_http_lua_socket_tcp_upstream_t*
---@field pattern ngx.str_t ngx_str_t
---@field state integer int
---@field recovering ngx_http_lua.dfa_edge_t[] ngx_http_lua_dfa_edge_t**
---@field inclusive boolean unsigned
local socket_compiled_pattern_t = class()

function socket_compiled_pattern_t:new()
	self.pattern = ngx_str_t()
	self.state = 0
	self.inclusive = false
end

return socket_compiled_pattern_t
