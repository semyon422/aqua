local class = require("class")

---@class icc.IQueue
---@operator call: icc.IQueue
local IQueue = class()

---@param msg any
function IQueue:push(msg) end

---@return any
function IQueue:pop() end

---@return integer
function IQueue:count() end

return IQueue
