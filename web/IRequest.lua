local class = require("class")

---@class web.IRequest
---@operator call: web.IRequest
---@field headers {[string]: string}
---@field method string
---@field uri string
local IRequest = class()

---@param size integer
---@return string
function IRequest:read(size)
	return ""
end

return IRequest
