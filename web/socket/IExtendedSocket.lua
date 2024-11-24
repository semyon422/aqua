local ISocket = require("web.socket.ISocket")

-- https://lunarmodules.github.io/luasocket/tcp.html
-- https://github.com/openresty/lua-nginx-module?tab=readme-ov-file#tcpsockreceive

---@class web.IExtendedSocket: web.ISocket
---@operator call: web.IExtendedSocket
local IExtendedSocket = ISocket + {}

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function IExtendedSocket:receive(pattern, prefix) end

---@param max integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function IExtendedSocket:receiveany(max) end

---@param pattern string
---@param options {inclusive: boolean?}?
---@return fun(size: integer?): string?, "closed"|"timeout"?, string?
function IExtendedSocket:receiveuntil(pattern, options) return function() end end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function IExtendedSocket:send(data, i, j) end

---@return 1
function IExtendedSocket:close() return 1 end

return IExtendedSocket
