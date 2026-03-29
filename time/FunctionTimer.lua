local ITimer = require("time.ITimer")

---@class time.FunctionTimer: time.ITimer
---@operator call: time.FunctionTimer
local FunctionTimer = ITimer + {}

---@param f fun(): number
function FunctionTimer:new(f)
	self.f = f
end

---@return number
function FunctionTimer:getTime()
	return self.f()
end

return FunctionTimer
