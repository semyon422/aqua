local class = require("class")

---@class web.IRequest
---@operator call: web.IRequest
---@field method string
---@field uri string
---@field protocol string
---@field headers web.IHeaders
local IRequest = class()

---@param body string?
function IRequest:write(body) end

---@param pattern "*a"|"*l"|integer?
---@return string
function IRequest:read(pattern)
	return ""
end

return IRequest
