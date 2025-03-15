local class = require("class")

---@class web.IResource
---@operator call: web.IResource
---@field uri string pattern
---@field [web.HttpMethod] fun(self: web.IResource, req: web.IRequest, res: web.IResponse, ctx: table)?
local IResource = class()

return IResource
