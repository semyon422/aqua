local class = require("class")

---@class web.IHeaders
---@operator call: web.IHeaders
local IHeaders = class()

---@param soc web.IAsyncSocket
---@return string?
---@return "closed"?
---@return string?
function IHeaders:receive(soc) end

---@param soc web.IAsyncSocket
---@return integer?
---@return "closed"?
---@return integer?
function IHeaders:send(soc) end

return IHeaders
