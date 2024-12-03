local class = require("class")

---@class web.IRequest: web.IExtendedSocket
---@operator call: web.IRequest
---@field method string
---@field uri string
---@field headers web.Headers
local IRequest = class()

return IRequest
