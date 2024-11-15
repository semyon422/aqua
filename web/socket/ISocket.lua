local class = require("class")

---@class web.ISocket
---@operator call: web.ISocket
local ISocket = class()

---@param size integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ISocket:receive(size) end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function ISocket:send(data, i, j) end

---@return 1
function ISocket:close() return 1 end

return ISocket
