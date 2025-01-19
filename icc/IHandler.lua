local class = require("class")

---@class icc.IHandler
---@operator call: icc.IHandler
local IHandler = class()

---@param th icc.TaskHandler
---@param peer icc.IPeer
---@param ... any
---@return any ...
function IHandler:handle(th, peer, ...) end

return IHandler
