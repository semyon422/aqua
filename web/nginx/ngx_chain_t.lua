local class = require("class")

---@class ngx.chain_t
---@operator call: ngx.chain_t
---@field buf ngx.buf_t ngx_buf_t*
---@field next ngx.chain_t ngx_chain_t*
local ngx_chain_t = class()

return ngx_chain_t
