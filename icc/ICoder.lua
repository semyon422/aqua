local class = require("class")

---@class icc.ICoder
---@operator call: icc.ICoder
local ICoder = class()

---@param v any
---@return string
function ICoder:encode(v)
	return v
end

---@param s string
---@return any
function ICoder:decode(s)
	return s
end

return ICoder
