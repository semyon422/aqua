local class = require("class")

---@class web.StaticContext
---@operator call: web.StaticContext
local StaticContext = class()

---@param prefix string
function StaticContext:new(prefix)
	self.prefix = prefix
	self.static = true
end

return StaticContext
