local class = require("class")

---@class time.ITimer
---@operator call: time.ITimer
local ITimer = class()

---@return number
function ITimer:getTime()
	error("not implemented")
end

return ITimer
