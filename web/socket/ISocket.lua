local class = require("class")

-- Only ExtendedSocket supports non-blocking sockets (timeout is 0) and has a buffer.
-- Other implementations must be without this, and can be wrapped in ExtendedSocket if necessary.
-- This limitation makes writing and testing code much easier.

---@class web.ISocket
---@operator call: web.ISocket
local ISocket = class()

---@param size integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ISocket:receive(size)
	error("not implemented")
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function ISocket:send(data, i, j)
	error("not implemented")
end

---@param size integer
---@return string?
---@return "closed"|"timeout"?
function ISocket:receiveany(size)
	local data, err, partial = self:receive(size)
	if data then
		return data
	end
	if #partial == 0 then
		return nil, err
	end
	return partial
end

---@return 1
function ISocket:close()
	error("not implemented")
end

return ISocket
