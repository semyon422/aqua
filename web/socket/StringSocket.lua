local ISocket = require("web.socket.ISocket")

---@class web.StringSocket: web.ISocket
---@operator call: web.StringSocket
local StringSocket = ISocket + {}

---@param data string?
---@param max_size integer?
function StringSocket:new(data, max_size)
	self.remainder = data or ""
	self.max_size = max_size or math.huge
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
	assert(type(size) == "number", "invalid size type")

	local rem = self.remainder

	if size <= #rem then
		self.remainder = rem:sub(size + 1)
		return rem:sub(1, size)
	end

	self.remainder = ""
	local err = self.closed and "closed" or "timeout"

	return nil, err, rem
end

---@param data string
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function StringSocket:send(data)
	if self.closed then
		return nil, "closed", 0
	end

	local data_size = #data
	local avail_size = self.max_size - #self.remainder

	if avail_size >= data_size then
		self.remainder = self.remainder .. data:sub(1, data_size)
		return data_size
	end

	self.remainder = self.remainder .. data:sub(1, avail_size)

	return nil, "timeout", avail_size
end

return StringSocket
