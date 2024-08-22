local class = require("class")

---@class icc.IPeer
---@operator call: icc.IPeer
local IPeer = class()

---@param data any
function IPeer:send(data) end

return IPeer
