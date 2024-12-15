local IExtendedSocket = require("web.socket.IExtendedSocket")

---@class web.RangeSocket: web.IExtendedSocket
---@operator call: web.RangeSocket
local RangeSocket = IExtendedSocket + {}

---@param soc web.IExtendedSocket
function RangeSocket:new(soc)
	self.soc = soc
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function RangeSocket:receive(pattern, prefix)
	return self.soc:receive(pattern, prefix)
end

---@param max integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function RangeSocket:receiveany(max)
	return self.soc:receiveany(max)
end

---@param pattern string
---@param options {inclusive: boolean?}?
---@return fun(size: integer?): string?, "closed"|"timeout"?, string?
function RangeSocket:receiveuntil(pattern, options)
	return self.soc:receiveuntil(pattern, options)
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function RangeSocket:send(data, i, j)
	i, j = self:normalize_bounds(data, i, j)

	local bytes, err, _bytes = self.soc:send(data:sub(i, j))

	local n = (bytes or _bytes) + i - 1

	if bytes then
		return n
	end

	return nil, err, n
end

---@return 1
function RangeSocket:close()
	return self.soc:close()
end

return RangeSocket
