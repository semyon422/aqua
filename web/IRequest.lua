local class = require("class")

---@class web.IRequest
---@operator call: web.IRequest
---@field headers web.IHeaders
---@field method string
---@field uri string
---@field protocol string
local IRequest = class()

---@param body string?
function IRequest:write(body) end

---@param size integer
---@return string
function IRequest:read(size)
	return ""
end

return IRequest
