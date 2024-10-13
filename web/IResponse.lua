local class = require("class")

---@class web.IResponse
---@operator call: web.IResponse
---@field protocol string
---@field status web.StatusCode
---@field headers web.IHeaders
local IResponse = class()

---@param body string?
function IResponse:write(body) end

---@param pattern "*a"|"*l"|integer?
---@return string
function IResponse:read(pattern)
	return ""
end

return IResponse
