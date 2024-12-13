local class = require("class")

---@class web.IResponse: web.IExtendedSocket, web.IRequestResponse
---@operator call: web.IResponse
---@field status integer
---@field headers web.Headers
local IResponse = class()

return IResponse
