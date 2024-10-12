local class = require("class")

-- same as ISocket but without "timeout"

---@class web.IAsyncSocket
---@operator call: web.IAsyncSocket
local IAsyncSocket = class()

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"?
---@return string?
function IAsyncSocket:receive(pattern, prefix) end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"?
---@return integer?
function IAsyncSocket:send(data, i, j) end

---@return 1
function IAsyncSocket:close() return 1 end

return IAsyncSocket
