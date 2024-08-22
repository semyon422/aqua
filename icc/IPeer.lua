local class = require("class")

---@class icc.IPeer
---@operator call: icc.IPeer
local IPeer = class()

---@param msg icc.Message
function IPeer:send(msg) end

return IPeer
