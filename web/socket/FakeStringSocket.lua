local ISocket = require("web.socket.ISocket")

---@class web.FakeStringSocket: web.ISocket
---@operator call: web.FakeStringSocket
local FakeStringSocket = ISocket + {}

---@param data string?
---@param max_size integer?
function FakeStringSocket:new(data, max_size)
	self.remainder = data or ""
	self.max_size = max_size or math.huge
end

---@return 1
function FakeStringSocket:close()
	self.closed = true
	return 1
end

---@param size integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function FakeStringSocket:receive(size, prefix)
	assert(type(size) == "number", "invalid size type")

	if prefix and size <= #prefix then
		return prefix
	end

	---@type string[]
	local buffer = {}
	table.insert(buffer, prefix)
	table.insert(buffer, self.remainder)

	self.remainder = nil

	local s = table.concat(buffer)

	---@type string?
	local ret
	ret, self.remainder = s:sub(1, size), s:sub(size + 1)

	if size <= #s then
		return ret
	end

	local err = self.closed and "closed" or "timeout"

	return nil, err, ret
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function FakeStringSocket:send(data, i, j)
	if self.closed then
		return nil, "closed", 0
	end

	i = i or 1
	j = j or #data

	local data_size = j - i + 1
	local avail_size = self.max_size - #self.remainder

	if avail_size >= data_size then
		self.remainder = self.remainder .. data:sub(i, j)
		return j
	end

	local last_byte = i + avail_size - 1
	self.remainder = self.remainder .. data:sub(i, last_byte)

	return nil, "timeout", last_byte
end

return FakeStringSocket
