local IHandler = require("icc.IHandler")

---@alias icc.HandlerFunc fun(self: icc.TaskHandler, peer: icc.IPeer, ...: any): ...: any

---@class icc.FuncHandler: icc.IHandler
---@operator call: icc.FuncHandler
local FuncHandler = IHandler + {}

---@param f icc.HandlerFunc
function FuncHandler:new(f)
	self.f = f
end

---@param th icc.TaskHandler
---@param peer icc.IPeer
---@param ... any
---@return any ...
function FuncHandler:handle(th, peer, ...)
	return self.f(th, peer, ...)
end

return FuncHandler
