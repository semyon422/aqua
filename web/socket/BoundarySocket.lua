local ISocket = require("web.socket.ISocket")

---@class web.BoundarySocket: web.ISocket
---@operator call: web.BoundarySocket
local BoundarySocket = ISocket + {}

---@param iterator fun(size?: integer): string?, "closed"|"timeout"?, string?
function BoundarySocket:new(iterator)
	self.iterator = iterator
	self.remainder = ""
end

---@private
---@param data string
---@return string
function BoundarySocket:resize_data(data, size)
	data, self.remainder = data:sub(1, size), data:sub(size + 1)
	return data
end

---@param size integer
---@return string?
---@return "closed"|"timeout"?
function BoundarySocket:receiveany(size)
	if self.closed then
		return nil, "closed"
	end

	local rem = self.remainder
	if #rem > 0 then
		return self:resize_data(rem, size)
	end

	local data, err, partial = self.iterator(size)
	if data then
		return self:resize_data(data, size)
	end

	err = err or "closed"
	if err == "closed" then
		self.closed = true
	end

	return nil, err
end

return BoundarySocket
