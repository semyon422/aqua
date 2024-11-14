local class = require("class")
local ffi = require("ffi")

---@class ngx.str_t
---@operator call: ngx.str_t
---@field len integer size_t
---@field data ffi.cdata* u_char*
local ngx_str_t = class()

---@param s string?
function ngx_str_t:new(s)
	s = s or ""
	self.len = #s
	self.data = ffi.new("uint8_t[?]", #s)
	ffi.copy(self.data, s, #s)
end

return ngx_str_t
