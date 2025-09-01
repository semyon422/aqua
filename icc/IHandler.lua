local class = require("class")

---@alias icc.IPeerContext table

---@class icc.IHandler
---@operator call: icc.IHandler
local IHandler = class()

---@param ctx icc.IPeerContext
---@param ... any
---@return any ...
function IHandler:handle(ctx, ...) end

return IHandler
