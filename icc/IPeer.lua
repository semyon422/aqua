local class = require("class")

---@class icc.IPeer
---@operator call: icc.IPeer
local IPeer = class()

---@param msg icc.Message
---@return integer?
---@return string?
function IPeer:send(msg) end

return IPeer
