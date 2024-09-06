local class = require("class")

-- https://lunarmodules.github.io/luasocket/tcp.html

---@class web.ISocket
---@operator call: web.ISocket
local ISocket = class()

---@param pattern "*a"|"*l"|integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ISocket:receive(pattern) end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function ISocket:send(data, i, j) end

return ISocket