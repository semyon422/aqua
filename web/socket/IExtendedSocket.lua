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
function IExtendedSocket:receive(pattern, prefix)
	error("not implemented")
end

---@param max integer
---@return string?
---@return "closed"|"timeout"?
function IExtendedSocket:receiveany(max) end

---@param pattern string
---@param options {inclusive: boolean?}?
---@return fun(size: integer?): string?, "closed"|"timeout"?, string?
function IExtendedSocket:receiveuntil(pattern, options)
	error("not implemented")
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function IExtendedSocket:send(data, i, j)
	error("not implemented")
end

---@return 1
function IExtendedSocket:close()
	error("not implemented")
end

return IExtendedSocket
