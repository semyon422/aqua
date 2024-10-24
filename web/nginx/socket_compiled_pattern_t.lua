local class = require("class")

---@class ngx_http_lua.socket_compiled_pattern_t
---@operator call: ngx_http_lua.socket_compiled_pattern_t
---@field upstream table ngx_http_lua_socket_tcp_upstream_t*
---@field pattern string ngx_str_t
---@field state integer int
---@field recovering ngx_http_lua.dfa_edge_t[] ngx_http_lua_dfa_edge_t**
---@field inclusive integer unsigned
local socket_compiled_pattern_t = class()

return socket_compiled_pattern_t
