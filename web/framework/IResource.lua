local class = require("class")

---@class web.IResource
---@operator call: web.IResource
---@field routes {[1]: string, [2]: {[web.HttpMethod]: string}}[]
---@field domains? string[] Optional domain patterns (e.g. "api.example.com", "c.*"). When present, routes match only requests whose Host header matches one of these patterns. Absent means match all domains.
local IResource = class()

return IResource
