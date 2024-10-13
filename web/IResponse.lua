local class = require("class")

---@class web.IResponse
---@operator call: web.IResponse
---@field protocol string
---@field status integer
---@field headers web.IHeaders
local IResponse = class()

---@param body string?
function IResponse:write(body) end

---@param size integer
---@return string
function IResponse:read(size)
	return ""
end

return IResponse
