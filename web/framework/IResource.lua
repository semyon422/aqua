local class = require("class")

---@class web.IResource
---@operator call: web.IResource
---@field routes {[1]: string, [2]: {[web.HttpMethod]: string}}[]
local IResource = class()

return IResource
