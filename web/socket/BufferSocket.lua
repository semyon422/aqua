local ISocket = require("web.socket.ISocket")

---@class web.BufferSocket: web.ISocket
---@operator call: web.BufferSocket
local BufferSocket = ISocket + {}

---@param soc web.ISocket
---@param max_size integer?
function BufferSocket:new(soc, max_size)
	self.soc = soc
	self.max_size = max_size or 4096
	self.remainder = ""
end

---@return 1
function BufferSocket:close()
	return self.soc:close()
end

---@param data string
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function BufferSocket:send(data)
	return self.soc:send(data)
end

---@param size integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function BufferSocket:receive(size)
	assert(type(size) == "number", "invalid size type")

	local rem = self.remainder
	local max_size = self.max_size

	if size <= #rem then
		self.remainder = rem:sub(size + 1)
		return rem:sub(1, size)
	end

	local line, err, partial = self.soc:receive(size + max_size - #self.remainder)

	local data = line or partial
	---@cast data string

	self.remainder = self.remainder .. data
	rem = self.remainder

	if size <= #rem then
		self.remainder = rem:sub(size + 1)
		return rem:sub(1, size)
	end

	self.remainder = ""

	return nil, err, rem
end

return BufferSocket
