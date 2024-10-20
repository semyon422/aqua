local class = require("class")

-- https://lunarmodules.github.io/luasocket/tcp.html

---@class web.ILuaSocket
---@operator call: web.ILuaSocket
local ILuaSocket = class()

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ILuaSocket:receive(pattern, prefix) end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function ILuaSocket:send(data, i, j) end

---@return 1
function ILuaSocket:close() return 1 end

return ILuaSocket
