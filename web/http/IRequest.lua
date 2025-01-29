local class = require("class")

---@class web.IRequest: web.IExtendedSocket, web.IRequestResponse
---@operator call: web.IRequest
---@field method web.HttpMethod
---@field uri string
---@field headers web.Headers
local IRequest = class()

return IRequest
