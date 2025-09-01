local IHandler = require("icc.IHandler")

---@alias icc.HandlerFunc fun(ctx: icc.IPeerContext, ...: any): ...: any

---@class icc.FuncHandler: icc.IHandler
---@operator call: icc.FuncHandler
local FuncHandler = IHandler + {}

---@param f icc.HandlerFunc
function FuncHandler:new(f)
	self.f = f
end

---@param ctx icc.IPeerContext
---@param ... any
---@return any ...
function FuncHandler:handle(ctx, ...)
	return self.f(ctx, ...)
end

return FuncHandler
