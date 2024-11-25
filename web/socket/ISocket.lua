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

---@param size integer
---@return string?
---@return "closed"|"timeout"?
function ISocket:receiveany(size)
	local data, err, partial = self:receive(size)
	data = data or partial
	if #data == 0 then
		return nil, err
	end
	return data
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
function ISocket:sendany(data, i, j)
	local last_byte, err, _last_byte = self:send(data, i, j)
	last_byte = last_byte or _last_byte
	if last_byte == 0 then
		return nil, err
	end
	return last_byte
end

---@return 1
function ISocket:close() return 1 end

return ISocket
