local class = require("class")

---@class ngx_http_lua.dfa_edge_t
---@operator call: ngx_http_lua.dfa_edge_t
---@field chr integer u_char
---@field new_state integer int
---@field next ngx_http_lua.dfa_edge_t ngx_http_lua_dfa_edge_t*
local dfa_edge_t = class()

return dfa_edge_t
