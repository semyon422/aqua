local ITimer = require("time.ITimer")

---@class time.LoveTimer: time.ITimer
---@operator call: time.LoveTimer
local LoveTimer = ITimer + {}

---@return number
function LoveTimer:getTime()
	return love.timer.getTime()
end

return LoveTimer
