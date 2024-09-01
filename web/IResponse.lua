local class = require("class")

---@class web.IResponse
---@operator call: web.IResponse
---@field status integer
---@field headers {[string]: any}
local IResponse = class()

---@param body string?
function IResponse:write(body) end

return IResponse
