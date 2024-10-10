local ISocket = require("web.socket.ISocket")

---@class web.FakeStringSocket: web.ISocket
---@operator call: web.FakeStringSocket
local FakeStringSocket = ISocket + {}

---@param data string
function FakeStringSocket:new(data)
	self.remainder = data
end

---@param size integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function FakeStringSocket:receive(size, prefix)
	assert(type(size) == "number", "invalid size type")

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

	return nil, "closed", ret
end

return FakeStringSocket
