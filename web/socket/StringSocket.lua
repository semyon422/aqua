local ISocket = require("web.socket.ISocket")

---@class web.StringSocket: web.ISocket
---@operator call: web.StringSocket
local StringSocket = ISocket + {}

---@param data string?
---@param max_size integer?
---@param yielding boolean?
function StringSocket:new(data, max_size, yielding)
	self.remainder = data or ""
	self.max_size = max_size or math.huge
	self.yielding = yielding or false
end

---@return 1
function StringSocket:close()
	self.closed = true
	return 1
end

---@param size integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function StringSocket:receive(size)
	local rem = self.remainder

	if size <= #rem then
		self.remainder = rem:sub(size + 1)
		return rem:sub(1, size)
	end

	if self.yielding and not self.closed then
		coroutine.yield()
		return self:receive(size)
	end

	self.remainder = ""
	local err = self.closed and "closed" or "timeout"

	return nil, err, rem
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function StringSocket:send(data, i, j)
	assert(not i and not j, "not implemented")

	if self.closed then
		return nil, "closed", 0
	end

	local rem = self.remainder
	local avail_size = self.max_size - #rem
	if avail_size >= #data then
		self.remainder = rem .. data
		return #data
	end

	if self.yielding then
		coroutine.yield()
		return self:send(data, i, j)
	end

	local last_byte = avail_size
	self.remainder = rem .. data:sub(1, last_byte)

	return nil, "timeout", last_byte
end

return StringSocket
